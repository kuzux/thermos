require "thermos/beverage"
require "thermos/dependency"
require "thermos/notifier"
require "thermos/refill_job"

module Thermos

  def self.keep_warm(cache_key:, primary_model:, primary_key:, dependencies: [], &block)
    fill(cache_key: cache_key, primary_model: primary_model, dependencies: dependencies, &block)
    drink(cache_key: cache_key, primary_key: primary_key)
  end

  def self.fill(cache_key:, primary_model:, dependencies: [], &block)
    @thermos ||= {}
    @thermos[cache_key] = Beverage.new(cache_key: cache_key, primary_model: primary_model, dependencies: dependencies, action: block)
  end

  def self.drink(cache_key:, primary_key:)
    Rails.cache.fetch([cache_key, primary_key]) do
      @thermos[cache_key].action.call(primary_key)
    end
  end

  def self.empty
    @thermos = {}
  end

  def self.refill_primary_caches(model)
    @thermos.values.select do |beverage|
      beverage.primary_model == model.class
    end.each do |beverage|
      refill(beverage, model.id)
    end
  end

  def self.refill_dependency_caches(model)
    @thermos.values.each do |beverage|
      dependencies = beverage.dependencies.select { |dependency| dependency.klass_name == model.class }
      dependencies.each do |dependency|
        beverage_models = beverage.primary_model.joins(dependency.association_name).where("#{dependency.table_name}.id = #{model.id}")
        beverage_models.each do |beverage_model|
          refill(beverage, beverage_model.id)
        end
      end
    end
  end

  def self.refill(beverage, primary_key)
    @thermos[beverage.cache_key] = beverage
    Rails.cache.write([beverage.cache_key, primary_key], beverage.action.call(primary_key))
  end
end
