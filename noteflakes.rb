# frozen_string_literal: true

require 'bundler/setup'
require 'tipi'

::Exception.__disable_sanitized_backtrace__ = true

certificate_db_path = File.expand_path('certificate_store.db', __dir__)
certificate_store = Tipi::ACME::SQLiteCertificateStore.new(certificate_db_path)

Tipi.full_service(
  certificate_store: certificate_store
) { |req| req.respond("Quand est née la reine d'angleterre?\nJe ne sais pas.", 'Content-Type' => 'text/plain') }
