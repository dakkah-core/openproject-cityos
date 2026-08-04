module OpenProject
  module CityosPortfolio
    # PEDD Engineering Universe Integration
    #
    # Bridges OpenProject work packages with the PEDD Super Engine's
    # Engineering Universe for:
    #   - Semantic entity lookups (capabilities, systems, domains)
    #   - Dependency graph enrichment from PEDD's relationship registry
    #   - Evidence cross-referencing with PEDD evidence ledger
    #
    # PEDD API endpoint: CITYOS_PEDD_API_URL (default: http://localhost:3100)
    class PeddIntegration
      PEDD_API = ENV.fetch('CITYOS_PEDD_API_URL', 'http://localhost:3100')

      # Query PEDD for entities related to a work package
      def self.query_related_entities(work_package_id)
        binding = OpenProject::CityOSGovernance::ScopeBinding
          .find_by(work_package_id: work_package_id)
        return { error: 'No scope binding for this work package' } unless binding

        entities = []

        # Look up by capability_id
        if binding.capability_id
          cap = pedd_get("/api/engineering-universe/capabilities/#{binding.capability_id}")
          entities << { type: 'capability', data: cap } if cap
        end

        # Look up by system_id
        if binding.system_id
          sys = pedd_get("/api/engineering-universe/systems/#{binding.system_id}")
          entities << { type: 'system', data: sys } if sys
        end

        # Look up evidence
        if binding.external_id
          evidence = pedd_get("/api/evidence/search?entity_id=#{binding.external_id}")
          entities << { type: 'evidence', count: evidence&.dig('total') || 0, items: evidence&.dig('items') } if evidence
        end

        { work_package_id: work_package_id, entities: entities }
      end

      # Enrich dependency graph with PEDD semantic relationships
      def self.enrich_dependency_graph(openproject_graph)
        return openproject_graph unless pedd_reachable?

        begin
          pedd_graph = pedd_get('/api/engineering-universe/dependency-graph')
          return openproject_graph unless pedd_graph

          # Merge PEDD nodes with OP nodes
          (pedd_graph['nodes'] || []).each do |pedd_node|
            existing = openproject_graph[:nodes].find { |n| n[:id] == pedd_node['id'] }
            if existing
              existing[:pedd_metadata] = pedd_node['metadata']
            else
              openproject_graph[:nodes] << {
                id: pedd_node['id'],
                label: pedd_node['name'] || pedd_node['id'],
                source: 'pedd',
                pedd_metadata: pedd_node['metadata']
              }
            end
          end

          # Merge PEDD edges
          (pedd_graph['edges'] || []).each do |pedd_edge|
            # Dedup: only add if not already present
            unless openproject_graph[:edges].any? { |e|
              e[:from] == pedd_edge['from'] && e[:to] == pedd_edge['to']
            }
              openproject_graph[:edges] << {
                from: pedd_edge['from'],
                to: pedd_edge['to'],
                type: pedd_edge['type'] || 'semantic',
                source: 'pedd'
              }
            end
          end

          openproject_graph
        rescue StandardError => e
          Rails.logger.warn("[PEDD Integration] Graph enrichment failed: #{e.message}")
          openproject_graph
        end
      end

      # Check PEDD reachability
      def self.pedd_reachable?
        pedd_get('/api/health')&.dig('status') == 'ok'
      rescue StandardError
        false
      end

      private

      def self.pedd_get(path)
        uri = URI("#{PEDD_API}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 5
        http.read_timeout = 5

        request = Net::HTTP::Get.new(uri)
        request['Accept'] = 'application/json'
        request['X-CityOS-Correlation-Id'] = SecureRandom.uuid

        response = http.request(request)
        return nil unless response.code.to_i == 200

        JSON.parse(response.body)
      rescue JSON::ParserError, Net::TimeoutError, Errno::ECONNREFUSED => e
        Rails.logger.debug("[PEDD Integration] PEDD not reachable: #{e.message}")
        nil
      end
    end
  end
end
