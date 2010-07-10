module Core
  def delay
    sleep SLEEP[rand(SLEEP.length)]
  end
end
