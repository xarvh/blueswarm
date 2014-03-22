ctx = null
body = null
rect = (x, y, w, h) -> ctx.fillRect x-w/2, y-h/2, w, h

#
#
#
drawCell = (cell) ->

  # isolate matrix operations
  ctx.save()

  ctx.translate cell.cx, cell.cy
  ctx.rotate cell.angle
  ctx.scale cell.width, cell.height

  # solid cell body
  e = cell.expression
  color = "rgba(#{Math.floor 85 * e[' ']}, #{Math.floor 128 * e['|']}, #{Math.floor 128 + 128 * e['^']/2}, .8)"
  ctx.fillStyle = color
  rect 0, 0, 1, 1

  # TODO: contour

  ctx.restore()


#
#
#
drawBody = (body) ->
  {min, max} = Math
  x = (c.cx for c in body.cells)
  y = (c.cy for c in body.cells)
  ox = (max(x...)+min(x...)) /2
  oy = (max(y...)+min(y...)) /2

  if !body.scale
    w = max(x...)-min(x...)
    h = max(y...)-min(y...)
    body.scale = 0.5 / max(w, h, body.root.width)

  ctx.save()
  ctx.scale body.scale, body.scale
  ctx.translate -ox, -oy
  for c in body.cells
    drawCell c
  ctx.restore()


#
#
#
draw = ->
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




window.onload = ->

  makeGenome = ->
    s = cell.CODE_SYMBOLS
    return (s[Math.floor Math.random() * s.length] for [1..1000]).join ''

  window.body = body = new cell.Body makeGenome()
  body.update()

  draw()

