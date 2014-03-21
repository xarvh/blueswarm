ctx = null

rect = (x, y, w, h) -> ctx.fillRect x-w/2, y-h/2, w, h





window.onload = ->
  ctx = document.getElementById('glcanvas').getContext('2d')
  window.ctx = ctx

  ctx.save()

  # Normalize geometry
  ctx.scale ctx.canvas.width, -ctx.canvas.height
  ctx.translate 0.5, -0.5

  ctx.fillStyle = '#09f'
  rect 0, 0, 0.5, 0.5




  ctx.restore()
