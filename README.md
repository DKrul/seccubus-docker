Seccubus Docker container
=========================

Container build for [https://seccubus.com/]. Maintained by the author of Seccubus

Usage
=====

Running a full stack (db/app/frontend) in a single container. And get an interactive shell
---

```
docker run -it seccubus /bin/bash
```

By default the container holds a MariaDB server that runs and stores data locally. If you want data persistency there are two options:

Mount a local filesystem to `/var/lib/mysql`
```
docker run -it seccubus -v /some/local/dir:/var/lib/mysql /bin/bash
```

Please be aware that you can only run one container at a time if you mount a local directory on /var/lib/mysql.

Alternativly you cloud connect the container to a remote mysql/MariaDB database with environment viariables:
```
docker run -ti seccubus -e DBHOST=dns.name.of.db.host \
-e DBPOSRT=3306 \
-e DBNAME=name.of.database \
-e DBUSER=db.username \
-e DBPASS=password \
/bin/bash
```


Running a scan
---
Run the following command to start the scan 'ssllabs' in workspace 'Example' (this workspace is created by default if you use the local mysql database)

```
docker run -ti seccubus scan Example ssllabs
```

Please be aware that you need soem data persistency here or the data will be stored in a local database that will be deleted whent he container terminates

Show this help message
---
```
docker run -ti seccubus help
```

Default command
---
If you don't specify a command to docker run
```
docker run seccubus
```
The apache access log and error log will be tailed to the screen.


Other options
---
You can set the following environment variables:

* STACK=(full|front|api|web|perl) - Determines which part of the stack is run
  - full - Run everything
  - front - Start apache to serve the html/javascript frontend (this requires that the APIURL variable is set too)
  - api - Start apache to serve the json api at / (starts MariaDB too if required)
  - web - Start apache to serve both the html/javascript frontend and the json
  - perl - Do not start apache, just use this container as an perl backend

 * DBHOST, DBPORT, DBNAME, DBUSER, DBPASS - Database connection parameters
   - If DBHOST/DBPORT are set to 127.0.0.1/3306 the local MariaDB instance is started

 * APIURL - Path to the API url
   - Set this if your set STACK to front to redirect the API calls to an alternative relative or absolute URL.

 * SMTPSERVER - IP address or host name of an SMTP server to be used for notifications

 * SMTPFROM - From address used in notifications

 * TICKETURL_HEAD/TICKETURL_TAIL - If these are set ticket numberrs will be linked to this URL
   - E.g. TICKERURL_HEAD = https://jira.atlassian.com/projects/SECC/issues/
   - TICKERURL_TAIL = ?filter=allopenissues
   - Ticket SECC-666 would be linked to https://jira.atlassian.com/projects/SECC/issues/SECC-666?filter=allopenissues