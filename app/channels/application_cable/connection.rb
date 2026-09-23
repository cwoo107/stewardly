module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_church, :current_user

    def connect
      self.current_church = Church.find_by_host_subdomain(request.subdomain) || reject_unauthorized_connection
      ActsAsTenant.with_tenant(current_church) { set_current_user } || reject_unauthorized_connection
    end

    private
      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.user
        end
      end
  end
end
