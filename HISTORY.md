HotTub Changelog
=====================

Head
=======

- Nothing yet

0.3.0
=======

- Drop EM support, will move to separate gem
- Simplify API with HotTub.new
- Use ThreadSafe::Cache for sessions
- Better documentation and lots of clean up
- HotTub::Reaper for reaping in separate thread
- HotTub::Pool now raises HotTub::Pool::Timeout instead of HotTub::BlockingTimeout
