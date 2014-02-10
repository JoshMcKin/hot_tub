HotTub Changelog
=====================

HEAD
=======

- Drop EM support, will move to separate gem
- Simplify API with HotTub.new
- Use ThreadSafe::Cache for threaded sessions
- Use Monitor in Pool
- Test and doc with Net::HTTP
- Place reaping in worker thread
