# frozen_string_literal: true

# CityOS patch: guard dynamic CSP source injection so malformed values
# such as "://" are never added to connect-src.
module DynamicContentSecurityPolicy
  extend ActiveSupport::Concern

  included do
    before_action :add_hocuspocus_host_to_csp
  end

  def append_content_security_policy_directives(directives)
    policy = current_content_security_policy
    directives.each do |directive, source_values|
      current_value = policy.send(directive) || policy.directives["default-src"]
      new_values =
        if current_value == %w('none') # rubocop:disable Lint/PercentStringArray
          source_values.compact.uniq
        else
          (current_value + source_values).compact.uniq
        end

      policy.send(directive, *new_values)
      request.content_security_policy = policy
    end
  end

  private

  def add_hocuspocus_host_to_csp
    hocuspocus_url = Setting.collaborative_editing_hocuspocus_url
    return if hocuspocus_url.blank?

    uri = begin
      URI.parse(hocuspocus_url)
    rescue URI::InvalidURIError
      OpenProject.logger.info do
        "Setting.collaborative_editing_hocuspocus_url is set to an invalid URI: #{hocuspocus_url}"
      end
      nil
    end

    source = csp_source_for_uri(uri)
    return if source.blank?

    append_content_security_policy_directives(connect_src: [source])
  end

  def csp_source_for_uri(uri)
    return nil if uri.blank?
    return nil if uri.scheme.blank?
    return nil if uri.host.blank?

    "#{uri.scheme}://#{host_with_port(uri)}"
  end

  def host_with_port(uri)
    default_port = %w[wss https].include?(uri.scheme) ? 443 : 80
    uri.port && uri.port != default_port ? "#{uri.host}:#{uri.port}" : uri.host
  end
end
