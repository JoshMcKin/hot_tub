HotTub Changelog
=====================

Head
=======

0.4.0
=======
- Hide HotTub::Sessions, should only be used with HotTub::Pool, otherwise just use ThreadSafe::Cache directly
- Reaper is now just a thread, and make sure we abort on exception
- add #reset! to Pool and Session for use after forking
- Test slow shutdowns
- Move integration tests and isolate
- General refactoring

0.3.0
=======

- Drop EM support, will move to separate gem
- Simplify API with HotTub.new
- Use ThreadSafe::Cache for sessions
- Better documentation and lots of clean up
- HotTub::Reaper for reaping in separate thread
- HotTub::Pool now raises HotTub::Pool::Timeout instead of HotTub::BlockingTimeout
