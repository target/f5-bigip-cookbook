module Helpers
  # f5-icontrol test helper functions
  module Utils
    def arrays_match?(arr1, arr2, sort_by = nil) # rubocop:disable AbcSize
      arr1 = arr1.uniq
      arr2 = arr2.uniq

      unless sort_by.nil?
        arr1.sort_by! { |e| sort_by.map { |s| e[s] } }
        arr2.sort_by! { |e| sort_by.map { |s| e[s] } }
      end

      return false unless arr1.size == arr2.size
      return false unless (arr1 & arr2).size == arr1.size
      true
    end

    def array_contains?(arr, contains)
      arr = arr.uniq
      contains = contains.uniq

      contains.each do |item|
        return false unless arr.include? item
      end
      true
    end

    # Adding chef_vault_item from chef-vault here as chef_vault_item
    # is normally only exposed to Recipe Class and I want to use in
    # Provider Class
    # TD: Figure out if there is a way to actually use chef_vault_item
    # From chef-vault cookbook in providers
    def chef_vault_item(bag, item)
      begin
        require 'chef-vault'
      rescue LoadError
        Chef::Log.warn("Missing gem 'chef-vault', use recipe[chef-vault] to install it first.")
      end

      if node['dev_mode']
        Chef::DataBagItem.load(bag, item)
      else
        ChefVault::Item.load(bag, item)
      end
    end
  end
end
