PSTDashboard::Application.routes.draw do
  #devise_for :users
  devise_for :users, :controllers => { :registrations => "registrations", :sessions => "sessions" }
  devise_scope :user do get '/users/sign_out' => 'sessions#destroy' end
  #devise_scope :user do match "/delete_users" => "registrations#delete_users", :as => 'delete_users' end

  match '/startengine' => 'job#start_engine', :as => 'start_engine', via: [:get, :post]
  match '/stopengine' => 'job#stop_engine', :as => 'stop_engine', via: [:get, :post]

  #match '/users/:id/edit' => 'admin_user_edit#edit', :as => :admin_user_edit
  match '/users/update' => 'admin_user_edit#update', :as => :admin_user_update, via: [:get, :post]
  match '/users/:id/list' => 'admin_user_edit#list', :as => :admin_user_list, via: [:get, :post]

   #match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase

  # introscope controller route
  match '/list_introscope_data', to: 'data_sharing#list_introscope_data', as: :list_introscope_data, via: :get

#  edit_job_metadata GET    /job_metadatas/:id/edit(.:format)  {:action=>"edit", :controller=>"job_metadatas"}
  match  '/job_metadatas/:id/update', to: 'job_metadatas#update', as: :job_metadatas_update, via: :patch

  #match  '/job_metadatas/:id/update', to: 'job_metadatas#update', as: :job_metadatas_update, via: :all

  match  '/job_metadatas/:id/edit' => 'job_metadatas#edit', :as => :job_metadatas_edit, via: [:get, :post]
  match  '/job_metadatas_list' => 'job_metadatas#list', :as => :job_metadatas_list, via: [:get, :patch]
  match  '/job_metadatas/:id' => 'job_metadatas#edit', :as => :job_metadata, via: [:get, :post]
  match  '/trackables' => 'job_metadatas#trackables', :as => :trackables, via: [:get, :post]
  match  '/trackables_refresh' => 'job_metadatas#auto_refresh', :as => :trackables_refresh, via: [:get, :post]

  #android_demo
  get '/android_demo' => 'android_demo#index', :as => :android_demo_index

  match '/mobile_trackable_list_json' => 'data_sharing#list_trackable_jobs_for_mobile', :as => :mobile_trackable_list, via: [:get]
  match '/mobile_nontrackable_list_json' => 'data_sharing#list_nontrackable_jobs_for_mobile', :as => :mobile_nontrackable_list, via: [:get]


#services
  match '/services_list' => 'service#list', :as => :services_list, via: [:get, :post]
  match '/service_show/:id' => 'service#show', :as => :service_show, via: [:get, :post]
  match '/service_execute/:id' => 'service#execute', :as => :service_execute, via: [:get, :post]
  match '/service_execute_with_params/:id' => 'service#execute_with_params', :as => :service_execute_with_params, via: [:get, :post]

#
  match '/job_log_list' => 'job_log_entries#list', :as => :job_log_list, via: [:get, :post]
  match '/job_log_entry/:id' => 'job_log_entries#show', :as => :job_log_entry, via: [:get, :post]
  match '/job_log_entry_email/:id' => 'job_log_entries#email_user', :as => :job_log_entry_email, via: [:get, :post]
  match '/job_log_list_refresh' => 'job_log_entries#auto_refresh', :as => :job_log_list_refresh, via: [:get, :post]

  #key value controller
  match '/key_value_fetch' => 'key_value#fetch', :as => :key_value_fetch, via: [:get, :post]

#job schedule viewer
  match '/job_schedule_cancel' => 'job_schedule#cancel', :as => :job_schedule_cancel, via: [:get, :post]
  match '/job_schedule_view' => 'job_schedule#view', :as => :job_schedule_view, via: [:get, :post]
  match '/job_schedule_edit' => 'job_schedule#edit', :as => :job_schedule_edit, via: [:get, :post]
  match '/job_schedule_update' => 'job_schedule#update', :as => :job_schedule_update, via: [:get, :post]
  match '/job_schedule_revert' => 'job_schedule#revert', :as => :job_schedule_revert, via: [:get, :post]

#  map.job_metadatas '/job_metadatas/:id/edit', :controller => 'job_metadatas', :action => 'edit'
  
  
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
#  match ':controller(/:action(/:id(.:format)))'

# The priority is based upon order of creation: first created -> highest priority.
# See how all your routes lay out with "rake routes".

# You can have the root of your site routed with "root"
# root 'welcome#index'

# Example of regular route:
#   get 'products/:id' => 'catalog#view'

# Example of named route that can be invoked with purchase_url(id: product.id)
#   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

# Example resource route (maps HTTP verbs to controller actions automatically):
#   resources :products

# Example resource route with options:
#   resources :products do
#     member do
#       get 'short'
#       post 'toggle'
#     end
#
#     collection do
#       get 'sold'
#     end
#   end

# Example resource route with sub-resources:
#   resources :products do
#     resources :comments, :sales
#     resource :seller
#   end

# Example resource route with more complex sub-resources:
#   resources :products do
#     resources :comments
#     resources :sales do
#       get 'recent', on: :collection
#     end
#   end

# Example resource route with concerns:
#   concern :toggleable do
#     post 'toggle'
#   end
#   resources :posts, concerns: :toggleable
#   resources :photos, concerns: :toggleable

# Example resource route within a namespace:
#   namespace :admin do
#     # Directs /admin/products/* to Admin::ProductsController
#     # (app/controllers/admin/products_controller.rb)
#     resources :products
#   end

end
