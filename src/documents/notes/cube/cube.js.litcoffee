WIDTH = 400
HEIGHT = 300
VIEW_ANGLE = 45
ASPECT = WIDTH / HEIGHT
NEAR = 0.1
FAR = 10000

make_vertices = (n) ->
  if n < 0
    assert false
  if n == 0
    return [[]]
  else
    ret = []
    for point in make_vertices(n-1)
      ret.push point.concat(-1)
      ret.push point.concat(1)
    return ret

make_edges = (n) ->
  vertices = make_vertices(n)
  lines = []
  for i in [0..vertices.length-2]
    for j in [i+1..vertices.length-1]
      if (k for k in [0..n-1] when vertices[i][k] != vertices[j][k]).length == 1
        lines.push [i, j]
  return lines

fact = _.memoize (n) ->
  if n <= 1
    return 1
  else
    return n * fact(n - 1)

matrix_exp = (mat, n) ->
  ret = numeric.identity mat.length
  mat_acc = numeric.identity mat.length
  for i in [1..n]
    mat_acc = numeric.dot mat_acc, mat
    ret = numeric.add(ret, numeric.mul((1.0 / fact(i)), mat_acc))
  return ret

zero_mat = (n) -> ((0 for i in [1..n]) for j in [1..n])

rotation_generator = (n, components) ->
  mat = zero_mat(n)
  i = 0
  j = 1
  for c in components
    mat[i][j] = c
    mat[j][i] = -c
    j += 1
    if j == n
      i += 1
      j = i+1
  return mat

apply_perspective = (pts) ->
  n = pts[0].length
  if n <= 3
    return pts
  return apply_perspective (numeric.div(p.slice(0, n-1), 3 - p[n-1]) for p in pts)

$(document).ready ->
  renderer = new THREE.WebGLRenderer()
  renderer.setSize WIDTH, HEIGHT

  scene = new THREE.Scene()

  camera = new THREE.PerspectiveCamera(VIEW_ANGLE, ASPECT, NEAR, FAR)
  camera.position.z = 10
  scene.add camera

  radius = .15
  segments = 16
  rings = 16
  ball_geom = new THREE.SphereGeometry radius, segments, rings
  material = new THREE.MeshLambertMaterial
      color: 0xCC0000

  dim = 5
  n_rotations = dim * (dim - 1) / 2
  vertices = make_vertices(dim)
  balls = []
  for [x, y, z, others...] in vertices
    ball = new THREE.Mesh ball_geom, material
    ball.position.set x, y, z
    balls.push ball
    #scene.add ball

  edges = make_edges(dim)
  lines = []
  for [i, j] in edges
    #[x1, y1, z1, others...] = vertices[i]
    #[x2, y2, z2, others...] = vertices[j]
    line_geom = new THREE.Geometry()
    line_geom.vertices.push(balls[i].position)
    line_geom.vertices.push(balls[j].position)
    line = new THREE.Line line_geom
    lines.push line
    scene.add line

  light = new THREE.PointLight 0xFFFFFF
  light.position.x = 10
  light.position.y = 50
  light.position.z = 130
  scene.add(light)
  $('#scene-container').append renderer.domElement

  generator = rotation_generator(dim, (.01 for i in [1..n_rotations]))
  rotator = matrix_exp(generator, 10)

  console.log(generator)
  console.log(rotator)

  controls = new THREE.TrackballControls camera
  console.log(controls)
  controls.keys = [65, 83, 68]
  controls.domElement.addEventListener 'change', render

  console.log $('#diminput')
  $('#diminput').change () ->
    console.log('here')
    n_dim = parseInt $('#diminput')[0].value
    n_axes = n_dim * (n_dim - 1) / 2
    $('#axis-container').empty()
    for i in [1..n_axes]
      $('#axis-container').append('<input type="number" value="1.0"/>')

  #$('axis-container').change () ->
  #  values = (parseInt input for input in $('axis-container'))
  #  values
  #

  render = () ->
    renderer.render(scene, camera)

  animate = () ->
    requestAnimationFrame animate
    if $('#updatecheck')[0].checked
      vertices = (numeric.dot(rotator, v) for v in vertices)
      for [ball, [x, y, z, others...]] in _.zip(balls, apply_perspective vertices)
        ball.position.set(x, y, z)
      for line in lines
        line.geometry.verticesNeedUpdate = true
    controls.update()
    render()
  
  animate()



  
