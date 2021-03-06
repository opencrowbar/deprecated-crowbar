# Copyright 2013, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
Crowbar::Application.routes.draw do

  # UI scope

  # special case items that allow IDs to have .s 
  constraints(:id => /.*/ ) do
    resources :nodes do
      resources :node_roles
      resources :attribs
    end
  end

  # UI resources (should generally match the API paths)
  get "annealer", :to => "node_roles#anneal", :as => :annealer
  resources :attribs
  resources :barclamps
  resources :deployments do
    get :head
    get :next
    resources :roles
  end
  resources :deployment_roles
  resources :docs, constraints: {id: /[^\?]*/}

  resources :groups
  resources :jigs
  resources :node_roles  do
    put :retry
  end
  resources :roles
  resources :snapshots do
    resources :node_roles
    get :graph
    get :cohorts
    put :propose
    put :commit
    put :recall
  end

  resources :interfaces
  resources :networks do
    resources :network_ranges
    resources :network_routers
    # special views
  end
  get 'network_map' => "networks#map", :as=> :network_map

  # UI only functionality to help w/ visualization
  scope 'dashboard' do
    get 'list(/:deployment)'  => 'dashboard#list', :as => :bulk_edit
    put 'list'                => 'dashboard#list', :as => :bulk_edit
    get 'layercake'           => 'dashboard#layercake', :as => :layercake
  end
  
  # UI only functionality to help w/ visualization
  scope 'utils' do
    get '/'             => 'support#index', :as => :utils
    get 'i18n/:id'      => 'support#i18n', :as => :utils_i18n, :constraints => { :id => /.*/ }
    get 'marker/:id'    => 'support#marker', :as => :utils_marker
    get 'files/:id'     => 'support#index', :as => :utils_files
    get 'import(/:id)'  => 'support#import', :as => :utils_import
    get 'upload/:id'    => 'support#upload', :as => :utils_upload
    get 'restart/:id'   => 'support#restart', :as => :restart
    get 'digest'        => "support#digest"
    get 'fail'          => "support#fail"
    get 'settings'      => "support#settings", :as => :utils_settings
    match "bootstrap"     => "support#bootstrap", :as => :bootstrap
    namespace :scaffolds do
      resources :attribs do as_routes end
      resources :barclamps do as_routes end
      resources :docs do as_routes end
      resources :deployments do as_routes end
      resources :deployment_roles do as_routes end
      resources :groups do as_routes end
      resources :jigs do as_routes end
      resources :navs do as_routes end
      resources :network_allocations do as_routes end
      resources :network_ranges do as_routes end
      resources :network_routers do as_routes end
      resources :networks do as_routes end
      resources :nodes do as_routes end
      resources :node_roles do as_routes end
      resources :roles do as_routes end
      resources :role_requires do as_routes end
      resources :runs do as_routes end
      resources :snapshots do as_routes end
    end
  end

  # UI scope - legacy methods
  scope 'support' do
    get 'logs', :controller => 'support', :action => 'logs'
    get 'get_cli', :controller => 'support', :action => 'get_cli'
  end

  devise_for :users, { :path_prefix => 'my', :module => :devise, :class_name=> 'Crowbar::User' }
  resources :users, :except => :new

  # API routes (must be json and must prefix v2)()
  scope :defaults => {:format => 'json'} do

    constraints(:id => /([a-zA-Z0-9\-\.\_]*)/, :version => /v[1-9]/) do

      # framework resources pattern (not barclamps specific)
      scope 'api' do
        scope 'status' do
          get "nodes(/:id)" => "nodes#status", :as => :nodes_status
          get "snapshots(/:id)" => "snapshots#status", :as => :snapshots_status
        end
        scope 'test' do
          put "nodes(/:id)" => "nodes#test_load_data"
        end
        scope ':version' do
          # These are not restful.  They poke the annealer and wait if you pass "sync=true".
          get "anneal", :to => "node_roles#anneal", :as => :anneal
          post "make_admin", :to => "nodes#make_admin", :as => :make_admin
          resources :attribs
          resources :barclamps
          resources :deployments do
            get :head
            get :next
            resources :roles
            resources :nodes
            put 'claim/:node_id' => "deployments#claim"
          end
          resources :deployment_roles do
            resources :attribs
          end
          resources :groups do
            member do
              get 'nodes'
            end
          end

          resources :networks do
            resources :network_ranges, :as => :network_ranges_api
            resources :network_routers, :as => :network_routers_api
            member do
              match 'ip'
              post 'allocate_ip'
              get 'allocations'
            end
          end
          resources :network_interfaces

          resources :runs
          resources :jigs
          resources :nodes do
            resources :node_roles
            resources :attribs
            resources :roles
            put :reboot
            put :debug
            put :undebug
          end
          resources :node_roles do
            put :retry
          end
          resources :roles do
            resources :deployment_roles
            put 'template/:key/:value' => "roles#template"
          end
          resources :snapshots do
            resources :node_roles
            resources :nodes
            resources :roles
            resources :deployment_roles
            get :graph
            put :propose
            put :commit
            put :recall
          end
          resources :users do
            post "admin", :controller => "users", :action => "make_admin"
            delete "admin", :controller => "users", :action => "remove_admin"
            post "lock", :controller => "users", :action => "lock"
            delete "lock", :controller => "users", :action => "unlock"
            put "reset_password", :controller => "users", :action => "reset_password"
          end

          #provisioner          
          get 'dhcp(/:id)' => 'Dhcps#index'

        end # version
      end # api
    end # id constraints
  end # json

  # Install route from each root barclamp (should be done last so CB gets priority)
  begin
    Barclamp.roots.each do |bc|
      eval(IO.read(File.path(bc.source_path, "rails", "config", "routes.rb")), binding) unless bc.name.eql? 'crowbar'
    end
  rescue
    # startup cannot resolve Barclamp
  end

  root :to => 'dashboard#layercake'
end
