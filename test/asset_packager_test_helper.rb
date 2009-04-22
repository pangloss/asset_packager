require 'test/unit'
require 'rubygems'
require 'mocha'
require 'yaml'

RAILS_ROOT = File.dirname(__FILE__) + "/fake_rails_root"

require 'action_controller'
require 'action_controller/test_process'

require 'synthesis/asset_package'
require 'synthesis/asset_package_helper'
ActionView::Base.send :include, Synthesis::AssetPackageHelper

ActionController::Base.logger = nil
ActionController::Routing::Routes.reload rescue nil

$asset_packages_yml = YAML.load_file( RAILS_ROOT + "/config/asset_packages.yml" )
$asset_base_path    = RAILS_ROOT + "/public"

class AssetPackageHelperTest < Test::Unit::TestCase
  include ActionController::Assertions::DomAssertions
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::AssetTagHelper
  include Synthesis::AssetPackageHelper
  
  def clean_backtrace(&block)
    yield
  end

  def setup
    Synthesis::AssetPackage.any_instance.stubs(:log)

    @controller = Class.new do
      def request
        @request ||= ActionController::TestRequest.new
      end
    end.new
  end

  def test_nothing
    true
  end

  def build_packages_once
    unless @packages_built
      Synthesis::AssetPackage.build_all
      @packages_built = true
    end
  end
  
  def build_js_expected_string(*sources)
    sources.map {|s| %(<script src="/javascripts/#{s}.js" type="text/javascript"></script>) }.join("\n")
  end
    
  def build_css_expected_string(*sources)
    sources.map {|s| %(<link href="/stylesheets/#{s}.css" rel="Stylesheet" type="text/css" media="screen" />) }.join("\n")
  end

end
