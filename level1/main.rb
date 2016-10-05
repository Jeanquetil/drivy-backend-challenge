require "json"
require 'date'

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
      Rental.new(rental["id"], set_car, rental["start_date"], rental["end_date"], rental["distance"])
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
  def initialize(id, car, start_date, end_date, distance)
    @id = id
    @car = car
    @start_date = start_date
    @end_date = end_date
    @distance = distance
  end

  def days
    (Date.parse(@end_date) - Date.parse(@start_date)).to_i + 1
  end

  def price
    days * @car.price_per_day + distance * @car.price_per_km
  end

  def to_hash
    {id: @id, price: price}
  end
end

# Running program
engine = Engine.new(data_read)
my_output = engine.rental_price_to_json

File.open('my_output.json', 'w') do |file|
  file.write(my_output)
end
