
class Roster
  def initialize(value)
    @value = value
  end

  def +(x)
    puts "#{@value} + #{x}"
    @value = @value + x
  end
  
  def -(x)
    puts "#{@value} - #{x}"
    @value = @value - x
  end
  
  def value=(value)
    puts "@value = #{value}"
    #@value = value
  end
  
  def value
    puts "@value? [#{@value}]"
    @value
  end
end

r = Roster.new(12)
puts r.value += 3
puts r.value -= 2
puts r.value