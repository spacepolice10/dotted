module ColourHelper
  def colour(colour_name)
    Colourable.colour_variable_of(colour_name)
  end

  def colour_bg(colour_name)
    Colourable.colour_bg_variable_of(colour_name)
  end
end
