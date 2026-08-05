require 'minitest/autorun'
require 'pathname'

strategy_path = Pathname('/tmp/oidc_strategy.rb')
require strategy_path.to_s

class OidcStrategyTest < Minitest::Test
  def test_client_options_use_the_configured_issuer_host
    original_issuer = ENV['CITYOS_OIDC_ISSUER']
    original_redirect = ENV['CITYOS_OIDC_REDIRECT_URI']

    ENV['CITYOS_OIDC_ISSUER'] = 'http://host.docker.internal:8180'
    ENV.delete('CITYOS_OIDC_REDIRECT_URI')

    options = OpenProject::CityosIdentity::OidcStrategy.client_options

    assert_equal 'http', options[:scheme]
    assert_equal 'host.docker.internal', options[:host]
    assert_equal 8180, options[:port]
    assert_equal 'http://host.docker.internal:8180/oauth/v2/authorize', options[:authorization_endpoint]
    assert_equal 'http://host.docker.internal:8180/oauth/v2/token', options[:token_endpoint]
    assert_equal 'http://host.docker.internal:8180/oidc/v1/userinfo', options[:userinfo_endpoint]
    assert_equal 'http://host.docker.internal:8180/oauth/v2/keys', options[:jwks_uri]
  ensure
    ENV['CITYOS_OIDC_ISSUER'] = original_issuer if original_issuer
    ENV['CITYOS_OIDC_REDIRECT_URI'] = original_redirect if original_redirect
  end
end
