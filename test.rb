class A

  def self.inherited(base)
    puts base.to_s
  end

puts "here"
end
class B < A
end
  

