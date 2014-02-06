HotTub Changelog
=====================

HEAD
=======

- Rename unsafe methods with leading "_"
- Add register to pool to track all connections
- Use ThreadSafe::Cache for threaded sessions
- Drop EM support, will move to separate gem
- Test and doc with Net::HTTP