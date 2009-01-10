module Synthesis
  module AssetPackageHelper
    
    def should_merge?
      AssetPackage.merge_environments.include?(RAILS_ENV)
    end

    def javascript_include_merged(*sources)
      options = sources.last.is_a?(Hash) ? sources.pop.stringify_keys : { }

      if sources.include?(:defaults) 
        sources = sources[0..(sources.index(:defaults))] + 
          ['prototype', 'effects', 'dragdrop', 'controls'] + 
          (File.exists?("#{RAILS_ROOT}/public/javascripts/application.js") ? ['application'] : []) + 
          sources[(sources.index(:defaults) + 1)..sources.length]
        sources.delete(:defaults)
      end

      sources.collect!{|s| s.to_s}
      sources = (should_merge? ? 
        AssetPackage.targets_from_sources("javascripts", sources) : 
        AssetPackage.sources_from_targets("javascripts", sources))
        
      sources.collect {|source| javascript_include_tag(append_js_ext(source), options) }.join("\n")
    end

    def stylesheet_link_merged(*sources)
      options = sources.last.is_a?(Hash) ? sources.pop.stringify_keys : { }

      sources.collect!{|s| s.to_s}
      sources = (should_merge? ? 
        AssetPackage.targets_from_sources("stylesheets", sources) : 
        AssetPackage.sources_from_targets("stylesheets", sources))

      sources.collect { |source|
        source = path_to_stylesheet(source)
        tag("link", { "rel" => "Stylesheet", "type" => "text/css", "media" => "screen", "href" => source }.merge(options))
      }.join("\n")
    end
    
    def merged_stylesheets(*sources)
      sources.collect!{|s| s.to_s}
      sources = (should_merge? ? 
        AssetPackage.targets_from_sources("stylesheets", sources) : 
        AssetPackage.sources_from_targets("stylesheets", sources))
      sources.collect! { |s| stylesheet_path(s) }
      sources
    end
    
    def merged_javascripts(*sources)
      sources.collect!{|s| s.to_s}
      sources = (should_merge? ? 
        AssetPackage.targets_from_sources("javascripts", sources) : 
        AssetPackage.sources_from_targets("javascripts", sources))
      sources.collect! { |s| javascript_path(s) }
      sources
    end
    
    private
    
    def append_js_ext(source)
      if source =~ /.*\.\d+/
        source + '.js'
      else
        source
      end
    end
    
  end
end