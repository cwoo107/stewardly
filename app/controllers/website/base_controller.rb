class Website::BaseController < ApplicationController
  before_action :set_site

  private
    def set_site
      @site = Site.current
    end

    def require_develop!
      authorize :website, :develop?
    end

    def require_manage!
      authorize :website, :update?
    end
end
