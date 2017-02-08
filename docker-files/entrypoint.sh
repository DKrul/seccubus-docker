#!/bin/bash -x

STACK=${STACK:-'full'}
DBHOST=${DBHOST:-'127.0.0.1'}
DBPORT=${DBPORT:-'3306'}
DBNAME=${DBNAME:-'seccubus'}
DBUSER=${DBUSER:-'seccubus'}
DBPASS=${DBPASS:-'seccubus'}

if [[ "$1" == "scan" ]]; then
    STACK="perl"
fi

# Check sanity of parameters
if [[ "$STACK" != "full" && "$STACK" != "front" && "$STACK" != "api" && "$STACK" != "web" && \
    "$STACK" != "perl" ]]; then
    cat <<EOM
\$STACK is currently \'$STACK\', it should be one of the following
* full - Run the full stack in a single container
* front - Run a web server to serve just the front end HTML, Javascript and related files
* api - Run a web server to serve just the JSON api
* web - Run a web server to serve both the API and front end HTML, javascript etc
* perl - Provide the Perl backend code, but not database or webserver
EOM
fi

# Set up web stack
if [[ "$STACK" == "full" || "$STACK" == "web" ]] ; then
    cp /full.conf /etc/httpd/conf.d/seccubus.conf
fi

if [[ "$STACK" == "front" ]] ; then
    cp /front.conf /etc/httpd/conf.d/seccubus.conf
    if [[ -z $APIURL ]]; then
        echo "\$STACK is set to '$STACK', but \$APIURL is empty, this won't work"
        exit
    else
        # Patch javascript to access remote URL
        sed -i.bak "s#\\\"json\\/\\\"#\"$APIURL\"#" /opt/seccubus/www/seccubus/production.js
    fi
fi

if [[ "$STACK" == "api" ]] ; then
    cp /api.conf /etc/httpd/conf.d/seccubus.conf
fi

if [[ "$STACK" == "full" || "$STACK" == "front" || "$STACK" == "api" || "$STACK" == "web" ]]; then
    # Need to start apache
    apachectl -DFOREGROUND &
fi

mkdir ~seccubus/.ssh
chmod 700 ~seccubus/.ssh
for KEY in `env|grep SSHKEY`; do
    SSHKEYNAME=$(echo $KEY|sed 's/\=.*$//')
    SSHKEYVAL=$(echo $KEY|sed 's/^.*\=//')
    echo $VAL > ~seccubus/.ssh/$SSHKEYNAME
    chmod 600 ~seccubus/.ssh/$SSHKEYNAME
    export $SSHKEYNAME=""
    SSHKEYNAME=""
    SSHKEYVAL=""
    KEY=""
done
chown -R seccubus:seccubus ~seccubus/.ssh

cat <<EOF >/opt/seccubus/etc/config.xml
<seccubus>
    <database>
        <engine>mysql</engine>
        <database>$DBNAME</database>
        <host>$DBHOST</host>
        <port>$DBPORT</port>
        <user>$DBUSER</user>
        <password>$DBPASS</password>
    </database>
    <paths>
        <modules>/opt/seccubus/SeccubusV2</modules>
        <scanners>/opt/seccubus/scanners</scanners>
        <bindir>/opt/seccubus/bin</bindir>
        <configdir>/opt/seccubus/etc</configdir>
        <dbdir>/opt/seccubus/db</dbdir>
    </paths>
    <smtp>
        <server>$SMTPSERVER</server>
        <from>$SMTPFROM</from>
    </smtp>
    <tickets>
        <url_head>$TICKETURL_HEAD</url_head>
        <url_tail>$TICKETURL_TAIL</url_tail>
    </tickets>
</seccubus>
EOF

# Let's figure out if we need a database...
if [[ "$DBHOST" == "127.0.0.1" && "$DBPORT" == "3306" ]]; then
    if [[ ! -e /var/lib/mysql/ibdata1 ]]; then
        # Assume that DB directory is unitialized
        /usr/bin/mysql_install_db --datadir="/var/lib/mysql" --user=mysql
    fi
    mysqld_safe & 
    sleep 3
    if [[ ! -d /var/lib/mysql/seccubus ]]; then
        /usr/bin/mysql -u root << EOF
            create database seccubus;
            grant all privileges on seccubus.* to seccubus@localhost identified by 'seccubus';
            flush privileges;
EOF
        /usr/bin/mysql -u seccubus -pseccubus seccubus < `ls /opt/seccubus/db/structure*.mysql|tail -1`
        /usr/bin/mysql -u seccubus -pseccubus seccubus < `ls /opt/seccubus/db/data*.mysql|tail -1`

        # Add example data
        cd /opt/seccubus/www/seccubus
        # Workspace
        json/createWorkspace.pl name=Example
        # Three scans
        json/createScan.pl workspaceId=100 name=ssllabs scanner=SSLlabs "password= " "parameters=--hosts @HOSTS --from-cache" targets=www.seccubus.com
        json/createScan.pl workspaceId=100 name=nmap scanner=Nmap "password= " 'parameters=-o "" --hosts @HOSTS' targets=www.seccubus.com
        json/createScan.pl workspaceId=100 name=nikto scanner=Nikto "password= " 'parameters=-o "" --hosts @HOSTS' targets=www.seccubus.com
    fi        
fi


case $1 in
"")
    tail -f /var/log/httpd/*log
    ;;
"scan")
    cd /opt/seccubus
    su - seccubus -c "bin/do-scan -w \"$2\" -s \"$3\""
    ;;
"help")
    echo
    echo
    cat /README.md
    ;;
*)
    exec "$@"
    ;;
esac