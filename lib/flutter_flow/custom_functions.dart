double? progressvalue(double? slidervalue) {
  // devide slidervalue with 100 and return valule
  if (slidervalue == null) return null; // Check for null
  return slidervalue / 100; // Divide by 100 and return
}
