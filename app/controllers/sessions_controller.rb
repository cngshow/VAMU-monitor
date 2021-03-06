class SessionsController < Devise::SessionsController
  prepend_view_path "app/views/devise"
  force_ssl only: [:new, :create], port: ENV['SSL_PORT'].to_i unless  ENV['SSL_PORT'].nil?


  def new
    @page_hdr = "Log in to your User Account-new"
    super
  end

  def create
    @page_hdr = "Log in to your User Account-create"
    offset = params[:hidTz]
    session[:tzOffset] = offset
    super
  end

  def destroy
    SingleUserResource.user_logged_out!(current_user)
    #terminate_session!("You have been logged out.")
    super
  end
end
