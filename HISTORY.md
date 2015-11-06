HotTub Changelog
=====================

Head
=======
- For Sessions, rename #add to #get_or_set for clarity, and alias with #add
- Fix Ruby warnings
- Prevent possible deadlock waiting for reaper to shutdown
- No need to reset reaper

0.5.2
=======
- Fix logger error

0.5.1
=======
- Add spawn_reaper to Reaper::Mixin.

0.5.0
=======
- Drop Thread::Safe dependency
- Make Sessions useful, complete re-write and provide global sessions support
- Refactor and clean up Pool
- Improve logging and add HotTub.trace for more detailed logs
- Name your pools and sessions for better logging
- Remove :on_reaper in favor of setting :reaper to false

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
