module OpenProject
  module CityOSPortfolio
    class Engine < ::Rails::Engine
      engine_name 'openproject_cityos_portfolio'

      include OpenProject::Plugins::ActsAsOpEngine

      register(
        'openproject-cityos-portfolio',
        author_url: 'https://github.com/dakkah-core/openproject-cityos',
        requires_openproject: '>= 17.0.0'
      ) do
        project_module :cityos_portfolio do
          permission :view_cityos_portfolio,
                     { 'cityos/portfolio': [:index, :systems, :rollups, :system_graph] },
                     public: false
          permission :manage_cityos_portfolio,
                     { 'cityos/portfolio': [:generate] },
                     require: :loggedin
        end

        menu :top_menu,
             :cityos_portfolio,
             { controller: '/cityos/portfolio', action: :index },
             caption: 'CityOS Portfolio',
             icon: 'cityos-portfolio',
             after: :projects
      end
    end
  end
end
