ctx = null
body = null
rect = (x, y, w, h) -> ctx.fillRect x-w/2, y-h/2, w, h

#
#
#
drawCell = (cell) ->

  # Isolate matrix operations
  ctx.save()
  ctx.translate cell.cx, cell.cy
  ctx.rotate cell.angle
  ctx.scale cell.height, cell.width

  # Solid cell body
  e = cell.expression
  color = "rgba(#{Math.floor 85 * e[' ']}, #{Math.floor 128 * e['|']}, #{Math.floor 128 + 128 * e['^']/2}, .8)"
  ctx.fillStyle = color
  rect 0, 0, 1, 1

  ctx.restore()


#
#
#
drawBody = (body) ->
  {min, max} = Math
  x = body.cells.map (c) -> c.cx
  y = body.cells.map (c) -> c.cy
  ox = (max(x...)+min(x...)) /2
  oy = (max(y...)+min(y...)) /2

  if !body.scale
    w = max(x...)-min(x...)
    h = max(y...)-min(y...)
    body.scale = 0.5 / max w, h, body.root.width

  ctx.save()
  ctx.scale body.scale, body.scale
  ctx.translate -ox, -oy
  for c in body.cells
    drawCell c
  ctx.restore()


#
#
#
animate = ->
  window.requestAnimationFrame animate

  body.animate 0.03

  ctx = document.getElementById('glcanvas').getContext('2d')
  window.ctx = ctx

  ctx.fillStyle = '#fff'
  ctx.fillRect 0, 0, ctx.canvas.width, ctx.canvas.height
  ctx.save()

  # Normalize geometry
  ctx.scale ctx.canvas.width, -ctx.canvas.height
  ctx.translate 0.5, -0.5

  # do stuff
  drawBody body

  ctx.restore()


#
# Fitness function: the most important piece of code
#
fitness_surface = (genome) ->

    {max, min} = Math

    # create the body to be evaluated
    body = new cell.Body genome
    body.animate 1

    # estimate body extension
    # --> select for spread bodies
    #
    x = body.cells.map (c) -> c.cx
    y = body.cells.map (c) -> c.cy
    w = max(x...) - min(x...)
    h = max(y...) - min(y...)
    body_extension = w * h
    if !body_extension
      return 0

    # calculate variance of cell sizes
    # --> select for similar cell sizes
    #
    sizes = body.cells.map (c) -> c.width * c.height
    x = sizes.reduce (sum, v) -> sum + v
    xx = sizes.reduce ((sum, v) -> sum + v*v), 0

    cells_variance = 1 + xx - x*x/sizes.length
    cells_surface = x

    # calculate distance from optimal ratio
    # --> select for optimal surface to extension ratio
    ratio = cells_surface / body_extension
    ideal_ratio = 0.5**2
    f = (ratio-ideal_ratio)**2

    # --> select for many cells
    # --> select against long genetic code
    f = ( body.cells.length/3 - genome.length/1000 ) / f / cells_variance
    return f


#
#
#
window.onload = ->

  {CODE_SYMBOLS} = cell

  #
  # Generate initial poulation
  #
  pop = evolve.makeRandomPopulation CODE_SYMBOLS

  #
  # Evolve
  #
  for generation in [1..20]
    console.log 'generation', generation

    newPop = {}
    for [1..20]
      genome = evolve.newGenomeFromPopulation pop, CODE_SYMBOLS, ' '
      newPop[genome] = fitness_surface genome

    pop = newPop

  #
  # Find best
  #
  best = ''
  for genome, fitness of pop
    unless fitness <= pop[best] then best = genome

  #
  # Render
  #
  window.body = body = new cell.Body best
  body.animate 0.03

  animate()

