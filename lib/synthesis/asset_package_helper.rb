module Synthesis
  module AssetPackageHelper
    
    def should_merge?
      AssetPackage.merge_environments.include?(RAILS_ENV)
    end

    def javascript_include_merged(*sources)

      if sources.include?(:defaults) 
        sources = sources[0..(sources.index(:defaults))] + 
          ['prototype', 'effects', 'dragdrop', 'controls'] + 
          (File.exists?("#{RAILS_ROOT}/public/javascripts/application.js") ? ['application'] : []) + 
          sources[(sources.index(:defaults) + 1)..sources.length]
        sources.delete(:defaults)
      end

      merged_javascripts(*sources).join("\n")
    end

    def stylesheet_link_merged(*sources)
      merged_stylesheets(*sources).join("\n")
    end
    
    # Get an array of merged stylesheet tags
    def merged_stylesheets(*sources)
      options = sources.last.is_a?(Hash) ? sources.pop.stringify_keys : { }
      
      sources.collect!{|s| s.to_s}
      sources = (should_merge? ? 
        AssetPackage.targets_from_sources("stylesheets", sources) : 
        AssetPackage.sources_from_targets("stylesheets", sources))
      sources.collect! { |source| 
        tag( "link", { 'rel' => 'Stylesheet', 'type' => 'text/css', 'media' => 'screen', 'href' => "/stylesheets/#{source}.css" }.merge(options))
      }
      sources
    end
    
    # Get an array of merged javascript tags
    def merged_javascripts(*sources)
      options = sources.last.is_a?(Hash) ? sources.pop.stringify_keys : { }
      
      sources.collect!{|s| s.to_s}
      sources = (should_merge? ? 
        AssetPackage.targets_from_sources("javascripts", sources) : 
        AssetPackage.sources_from_targets("javascripts", sources))
      sources.collect! { |source| 
        tag( "script", { 'type' => 'text/javascript', 'src' => "/javascripts/#{source}.js" }.merge(options), true ) + '</script>'
      }
      sources
    end
        
  end
end