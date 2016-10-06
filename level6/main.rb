require "json"
require 'date'
require 'active_model'

data_path = 'data.json'
data_read = File.read(data_path)

# Engine that read input and render rental's prices
class Engine
  attr_reader :cars, :rentals

  def initialize(data_read)
    @data = JSON.parse(data_read)
    @cars = @data['cars'].map {|car| Car.new(car) }
    @rentals = @data['rentals'].map do |rental|
      set_car = @cars.find { |car| car.id == rental["car_id"]}
      Rental.new(rental.merge(car: set_car))
    end
    @rental_modifications = @data['rental_modifications'].map do |rental_modification|
      set_rental = @rentals.find { |rental| rental.id == rental_modification["rental_id"]}
      RentalModification.new(rental_modification.merge(rental: set_rental))
    end
  end

  def rental_price_to_json
    JSON.pretty_generate({rentals: @rentals.map(&:to_hash)})
  end

  def rental_price_modification_to_json
    JSON.pretty_generate({rental_modifications: @rental_modifications.map(&:to_hash)})
  end
end

# Car Object
class Car
  include ActiveModel::Model
  attr_accessor :id, :price_per_day, :price_per_km
end

# Rental Object
class Rental
  include ActiveModel::Model
  attr_accessor :id, :car_id, :car, :start_date, :end_date, :distance, :deductible_reduction, :actions

  def days
    (Date.parse(@end_date) - Date.parse(@start_date)).to_i + 1
  end

  def price
    decreasing_days = 0
    (1..days).to_a.each do |day|
      decreasing_days += case
        when day > 10 then 0.5
        when day > 4 then 0.7
        when day > 1 then 0.9
        when day = 1 then 1
      end
    end
    (distance * @car.price_per_km + decreasing_days * @car.price_per_day).to_i
  end

  def commission
    Commission.new(self)
  end

  def deductible_reduc
    @deductible_reduction == true ? days * 400 : 0
  end

  def compute_actions
    @actions = []
    @actions << Action.new(who: 'driver', type: 'debit', amount: deductible_reduc + price).to_hash
    @actions << Action.new(who: 'owner', type: 'credit', amount: price - commission.total_commission).to_hash
    @actions << Action.new(who: 'insurance', type: 'credit', amount: commission.insurance_fee).to_hash
    @actions << Action.new(who: 'assistance', type: 'credit', amount: commission.assistance_fee).to_hash
    @actions << Action.new(who: 'drivy', type: 'credit', amount: commission.drivy_fee + deductible_reduc).to_hash
  end

  def to_hash
    {id: @id, actions: compute_actions}
  end
end

# Commission Object
class Commission
  attr_reader :total_commission, :insurance_fee, :assistance_fee, :drivy_fee
  def initialize(rental)
    @total_commission = (rental.price * 0.3).to_i
    @insurance_fee = (@total_commission * 0.5).to_i
    @assistance_fee = 100 * rental.days
    @drivy_fee = (@total_commission - @insurance_fee - @assistance_fee).to_i
  end
end

# Action Object
class Action
  include ActiveModel::Model
  attr_accessor :who, :type, :amount

  def to_hash
    {who: @who, type: @type, amount: @amount}
  end
end

# Rental Modification Object
class RentalModification
  include ActiveModel::Model
  attr_accessor :id, :rental_id, :rental, :start_date, :end_date, :distance, :deductible_reduction

  def compute_new_actions
    new_rental = Rental.new(car: @rental.car,
                            start_date: start_date || @rental.start_date,
                            end_date: end_date || @rental.end_date,
                            distance: distance || @rental.distance,
                            deductible_reduction: @rental.deductible_reduction)
    new_rental.price
    new_rental.compute_actions
    self.rental.compute_actions
    new_rental.actions.each_with_index do |new_action, index|
      new_action[:amount] -= rental.actions[index][:amount]
      if new_action[:amount] < 0
        new_action[:amount] = new_action[:amount].abs
        new_action[:type] == "debit" ? new_action[:type] = "credit" : new_action[:type] = "debit"
      end
    end
  end

  def to_hash
    {id: id, rental_id: rental_id, actions: compute_new_actions}
  end
end

# Running program
engine = Engine.new(data_read)
my_output = engine.rental_price_modification_to_json

# Writing output results
File.open('my_output.json', 'w') do |file|
  file.write(my_output)
end
