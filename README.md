Circle version 0.03
===================

Circle is an IRC logging application. More will be said when it actually
works. At first it will just do logging. Then I'll add a Catalyst-driven UI
for looking at and searching the logs. Then I'll think about securty,
factoids, and perhaps a pastebot. Stay tuned

INSTALLATION

To install this application, edit `conf/prod.yml` with your database connection
information, and then type the following:

    perl Build.PL
    ./Build --context prod
    ./Build
    ./Build db
    ./script/circle_server.pl

Copyright and Licence
---------------------

Copyright (c) 2009 David E. Wheeler. Some Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
