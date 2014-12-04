require './lib/helpers'

class RegistrationsController < Devise::RegistrationsController
  prepend_view_path "app/views/devise"
  #force_ssl only: [:new, :edit, :create, :update], port: 3443
  force_ssl only: [:new, :edit, :create, :update], port: ENV['SSL_PORT'].to_i unless  ENV['SSL_PORT'].nil?

  def new
    @page_hdr = "Create a New User Account"
    super
  end

  def create
    @page_hdr = "Create a User Registration Account"
    offset = params[:hidTz]
    session[:tzOffset] = offset

    # Generate your profile here
    super
  end

  def update
    @page_hdr = "User Registration Update"
    super
  end

  def edit
   @page_hdr = "User Registration Edit"
   @user_count = User.count
   @admin_count = User.where(administrator: true).count
   super
  end

  protected
  def devise_parameter_sanitizer
    DeviseHelpers::ParameterSanitizer.new(User, :user, params)
  end

end
