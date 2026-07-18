# Petites Dents App Store API helpers

These scripts are app-local and use App Store Connect API credentials supplied
through `ASC_API_KEY_PATH` or the `APP_STORE_CONNECT_API_KEY_*` environment
variables. No credential belongs in this repository.

The helpers create the bundle/app/version, reconcile the age rating, keep the
upfront price free, create only the three optional tip products, select the
exact processed build, submit review items, and read the result back. They do
not use TestFlight.

`generate_screenshots.rb` creates only run-owned simulators in the default
device set, captures the complete locale × device × scene matrix, and deletes
the exact owned UDIDs. `media_contract.rb` binds that matrix to a clean Git
revision and verifies dimensions and checksums before upload.
