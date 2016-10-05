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
    @cars = @data['cars'].map {|car| Car.new(car["id"], car["price_per_day"], car["price_per_km"])}
    @rentals = @data['rentals'].map do |rental|
      set_car = @cars.find { |car| car.id == rental["car_id"]}
      Rental.new(rental["id"], set_car, rental["start_date"], rental["end_date"], rental["distance"], rental["deductible_reduction"])
    end
  end

  def rental_price_to_json
    JSON.pretty_generate({rentals: @rentals.map(&:to_hash)})
  end
end

# Car Object
class Car
  attr_reader :id, :price_per_day, :price_per_km

  def initialize(id, price_per_day, price_per_km)
    @id = id
    @price_per_day = price_per_day
    @price_per_km = price_per_km
  end
end

# Rental Object
class Rental
  attr_reader :id, :car, :start_date, :end_date, :distance
  def initialize(id, car, start_date, end_date, distance, deductible_reduction)
    @id = id
    @car = car
    @start_date = start_date
    @end_date = end_date
    @distance = distance
    @deductible_reduction = deductible_reduction
    @actions = []
  end

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

  def deductible_reduction
    @deductible_reduction == true ? days * 400 : 0
  end

  def compute_actions
    @actions << Action.new(who: 'driver', type: 'debit', amount: deductible_reduction + price).to_hash
    @actions << Action.new(who: 'owner', type: 'credit', amount: price - commission.total_commission).to_hash
    @actions << Action.new(who: 'insurance', type: 'credit', amount: commission.insurance_fee).to_hash
    @actions << Action.new(who: 'assistance', type: 'credit', amount: commission.assistance_fee).to_hash
    @actions << Action.new(who: 'drivy', type: 'credit', amount: commission.drivy_fee + deductible_reduction).to_hash
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
  attr_reader :who, :type, :amount
  def initialize(attributes = {})
    @who = attributes[:who]
    @type = attributes[:type]
    @amount = attributes[:amount]
  end

  def to_hash
    {who: @who, type: @type, amount: @amount}
  end
end

# Running program
engine = Engine.new(data_read)
my_output = engine.rental_price_to_json

File.open('my_output.json', 'w') do |file|
  file.write(my_output)
end
