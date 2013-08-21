Mendalert
=========

overview
--------
A perl script which, when cronned, checks a public mendeley group and checks if there are have been
any recently added papers. For some reason, the notification system for papers in mendeley is broken.

required packages
-----------------
use MIME::Lite;

use Mail::Sendmail;

use LWP::Simple;

use JSON;

use pQuery;


usage
-----


what do?
--------

First, the script loads some external data which is stored as JSON. The old ds is variable holds 
the JSON from an API request.

The emails variable holds an arrayref of email addresses which will be notified when a new paper has been
added. A valid DS looks like :

```perl
$emails = ['hello@gmail.com','world@gmail.com'];
```   

The Keys variable holds two key numbers, the group number and a mendeley api consumer key (register for 
one at mendeley.com). They are in a hash:

```perl
$keys = {'group_id' = '12344321','consumer_key'='74830217480732184903217489032174809321' };
```

The script uses a get request on the mendeley api to check how many papers are added to the group.
If its bigger than the cached version, it sends an email. 
