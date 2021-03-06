module Synthesis
  class AssetPackage    
          
    @@merge_environments = ["production"]

    @@asset_packages_yml = $asset_packages_yml || 
      (File.exists?("#{RAILS_ROOT}/config/asset_packages.yml") ? YAML.load_file("#{RAILS_ROOT}/config/asset_packages.yml") : nil)
  
    # singleton methods
    class << self
      
      def merge_environments
        @@merge_environments
      end
      
      def merge_environments=(v)
        @@merge_environments = v
      end
      
      def parse_path(path)
        /^(?:(.*)\/)?([^\/]+)$/.match(path).to_a
      end

      def find_by_type(asset_type)
        @@asset_packages_yml[asset_type].map { |p| self.new(asset_type, p) }
      end

      def find_by_target(asset_type, target)
        package_hash = @@asset_packages_yml[asset_type].find {|p| p.keys.first == target }
        package_hash ? self.new(asset_type, package_hash) : nil
      end

      def find_by_source(asset_type, source)
        path_parts = parse_path(source)
        package_hash = @@asset_packages_yml[asset_type].find do |p|
          key = p.keys.first
          p[key].include?(path_parts[2]) && (parse_path(key)[1] == path_parts[1])
        end
        package_hash ? self.new(asset_type, package_hash) : nil
      end

      def targets_from_sources(asset_type, sources)
        package_names = Array.new
        sources.each do |source|
          package = find_by_target(asset_type, source) || find_by_source(asset_type, source)
          package_names << (package ? package.current_file : source)
        end
        package_names.uniq
      end

      def sources_from_targets(asset_type, targets)
        source_names = Array.new
        targets.each do |target|
          package = find_by_target(asset_type, target)
          source_names += (package ? package.sources.collect do |src|
            package.target_dir.gsub(/^(.+)$/, '\1/') + src
          end : target.to_a)
        end
        source_names.uniq
      end

      def lint_all
        @@asset_packages_yml.each_pair do |asset_type,assets|
          assets.each { |p| self.new(asset_type, p).lint }
        end
      end

      def build_all
        @@asset_packages_yml.each_pair do |asset_type,assets|
          assets.each { |p| self.new(asset_type, p).build }
        end
      end

      def delete_all
        @@asset_packages_yml.each_pair do |asset_type,assets|
          assets.each { |p| self.new(asset_type, p).delete_all_builds }
        end
      end

      def create_yml
        unless File.exists?("#{RAILS_ROOT}/config/asset_packages.yml")
          asset_yml = Hash.new

          asset_yml['javascripts'] = [{"base" => build_file_list("#{RAILS_ROOT}/public/javascripts", "js")}]
          asset_yml['stylesheets'] = [{"base" => build_file_list("#{RAILS_ROOT}/public/stylesheets", "css")}]

          File.open("#{RAILS_ROOT}/config/asset_packages.yml", "w") do |out|
            YAML.dump(asset_yml, out)
          end

          log "config/asset_packages.yml example file created!"
          log "Please reorder files under 'base' so dependencies are loaded in correct order."
        else
          log "config/asset_packages.yml already exists. Aborting task..."
        end
      end

    end
    
    # instance methods
    attr_accessor :asset_type, :target, :target_dir, :sources
  
    def initialize(asset_type, package_hash)
      target_parts = self.class.parse_path(package_hash.keys.first)
      @target_dir = target_parts[1].to_s
      @target = target_parts[2].to_s
      @sources = package_hash[package_hash.keys.first]
      @asset_type = asset_type
      @asset_path = ($asset_base_path ? "#{$asset_base_path}/" : "#{RAILS_ROOT}/public/") +
          "#{@asset_type}#{@target_dir.gsub(/^(.+)$/, '/\1')}"
      @extension = get_extension
      @match_regex = Regexp.new("\\A#{@target}_[0-9a-fA-F]+.#{@extension}\\z")
    end
  
    def current_file
      @target_dir.gsub(/^(.+)$/, '\1/') +
          Dir.new(@asset_path).entries.delete_if { |x| ! (x =~ @match_regex) }.sort.reverse[0].chomp(".#{@extension}")
    end

    def build
      delete_old_builds
      create_new_build
    end
  
    def delete_old_builds
      Dir.new(@asset_path).entries.delete_if { |x| ! (x =~ @match_regex) }.each do |x|
        File.delete("#{@asset_path}/#{x}") unless x.index(revision.to_s)
      end
    end

    def delete_all_builds
      Dir.new(@asset_path).entries.delete_if { |x| ! (x =~ @match_regex) }.each do |x|
        File.delete("#{@asset_path}/#{x}")
      end
    end
    
    def lint
      if @asset_type == "javascripts"
        (@sources - %w(prototype effects dragdrop controls)).each do |s|
          puts "==================== #{s}.#{@extension} ========================"
          system("java -jar #{lib_path}/yuicompressor-2.4.2.jar --type js -v #{full_asset_path(s)} >/dev/null")
        end
      end
    end

    private
      def revision
        unless @revision

          # If the REVISION file exists, just use it to specify the revision information
          revision_file_path = File.join( RAILS_ROOT, "REVISION" )
          return @revision = File.read( revision_file_path ).strip if File.exist?( revision_file_path )

          revisions = [1]
          @sources.each do |source|
            revisions << get_file_revision("#{@asset_path}/#{source}.#{@extension}")
          end
          @revision = revisions.max
        end
        @revision
      end

      def get_file_revision(path)
        begin
          `svn info #{path} 2> /dev/null`[/Last Changed Rev: (.*?)\n/][/(\d+)/].to_i
        rescue
          `git-log -1 --pretty=format:"%at" 2>/dev/null`.to_i
        rescue # use filename timestamp if all else fails
          File.mtime(path).to_i
        rescue
          0
        end
      end

      def create_new_build
        if File.exists?("#{@asset_path}/#{@target}_#{revision}.#{@extension}")
          log "Latest version already exists: #{@asset_path}/#{@target}_#{revision}.#{@extension}"
        else
          File.open("#{@asset_path}/#{@target}_#{revision}.#{@extension}", "w") {|f| f.write(compressed_file) }
          log "Created #{@asset_path}/#{@target}_#{revision}.#{@extension}"
        end
      end
      
      def full_asset_path(source)
        "#{@asset_path}/#{source}.#{@extension}"
      end

      def merged_file
        result = ""
        @sources.each {|s| 
          File.open(full_asset_path(s), "r") { |f| 
            asset_content = f.read
            case @asset_type
            when 'stylesheets'
              # Fix relative urls in url()
              asset_content.gsub!(%r{
                \b
                (url[(]\s*)           # Emulate look behind assertion, match "url("
                (?=                   # Look ahead assertion to match relative path
                  [^/:\s](?!://)        # Not start with /:, and make sure it isn't
                  (?:[^)](?!://))+\)    # a absolute path with protocol prefix
                )
                }x,
                "\\1#{File.dirname(s)}/"
              )
            end
            result << asset_content << "\n"
          }
        }
        result
      end
    
      def compressed_file
        case @asset_type
          when "javascripts" then compress_js(merged_file)
          when "stylesheets" then compress_css(merged_file)
        end
      end

      def compress_js(source)
        compress_with_yui(source,:js) || compress_with_jsmin(source)
      end
       
      def compress_css(source)
        compress_with_yui(source,:css) || compress_with_regexp(source)
      end
      
      # Compress asset using YUI
      # source - asset source
      # type - asset type, one of [js,css]
      def compress_with_yui(source,type)        
        begin
          result = nil
          
          # attempt to use YUI compressor
          IO.popen "java -jar #{lib_path}/yuicompressor-2.4.2.jar --type #{type} 2>/dev/null", "r+" do |f|
            f.write source
            f.close_write
            result = f.read
          end
          
          return nil unless $?.success?
        
          result
        rescue
          return nil
        end
      end
      
      # Compress asset using JSMIN
      def compress_with_jsmin(source)
        # fallback to included ruby compressor
        tmp_path = "#{RAILS_ROOT}/tmp/#{@target}_#{revision}"

        # write out to a temp file
        File.open("#{tmp_path}_uncompressed.js", "w") {|f| f.write(source) }
          
        # apply JSMIN compressor
        `ruby #{lib_path}/jsmin.rb <#{tmp_path}_uncompressed.js >#{tmp_path}_compressed.js \n`

        # read it back in and trim it
        result = ""
        File.open("#{tmp_path}_compressed.js", "r") { |f| result += f.read.strip }

        # delete temp files if they exist
        File.delete("#{tmp_path}_uncompressed.js") if File.exists?("#{tmp_path}_uncompressed.js")
        File.delete("#{tmp_path}_compressed.js") if File.exists?("#{tmp_path}_compressed.js")

        return result
      end
      
      # Compress asset using set of regular expressions
      def compress_with_regexp(source)
        source.gsub!(/\/\*(.*?)\*\//m, "") # remove comments - caution, might want to remove this if using css hacks
        source.gsub!(/\s+/, " ")           # collapse space
        source.gsub!(/\} /, "}\n")         # add line breaks
        source.gsub!(/\n$/, "")            # remove last break
        source.gsub!(/ \{ /, " {")         # trim inside brackets
        source.gsub!(/; \}/, "}")          # trim inside brackets
        source
      end
      
      def lib_path
        File.dirname(__FILE__) + "/../" # Path to library dir with YUI and JSMIN
      end

      def get_extension
        case @asset_type
          when "javascripts" then "js"
          when "stylesheets" then "css"
        end
      end
      
      def log(message)
        self.class.log(message)
      end
      
      def self.log(message)
        puts message
      end

      def self.build_file_list(path, extension)
        re = Regexp.new(".#{extension}\\z")
        file_list = Dir.new(path).entries.delete_if { |x| ! (x =~ re) }.map {|x| x.chomp(".#{extension}")}        
        file_list.reverse! if extension == "js" # reverse javascript entries so prototype comes first on a base rails app
        file_list
      end
   
  end
end
