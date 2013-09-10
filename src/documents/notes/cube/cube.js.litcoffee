# Hypercubes in CoffeeScript and WebGL

Let's define some constants for WebGL's sake

    WIDTH = 400
    HEIGHT = 300
    VIEW_ANGLE = 45
    ASPECT = WIDTH / HEIGHT
    NEAR = 0.1
    FAR = 10000

A cube is a simple thing. The most natural definition is recursive.  A line is
two points, separated and connected.  A square is two lines, separated, and
connected pointwise.  An N-cube is a pair of (N-1)-cubes, separated in the new
N-th dimension, with edges strung together so that the k-th point on the first
(N-1)-cube is connected to the k-th point of the second.

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

A hypercube is pretty boring if we can't move it around. Let's talk rotations.  In 1D we
don't have any rotations. In 2D we have one (take your piece of paper and spin it around).
In 3D we have three rotations. One is tempted to say that there is one rotation for each
axis, which is true, but is misleading. We really have one rotation for each pair of
(non-identical) axes. So "rotation about x" is really just "rotation that takes y into z".
It just so happens that (3 choose 2) = 3. In N dimensions, then, we have 
\\[\binom{N}{2} = \frac{N(N-1)}{2}\\] rotations. But now we want to actually construct some
rotations! Well, somehow we need to incorporate the notion of an angle. In 3D we may have
3 directions to rotate, but we have a continuum of rotations along each axis. At the end
of the day, we want to create a matrix we can apply to a vector to rotate it, but we want
to get there by starting with a 'direction' and applying an angle. It turns out the way to
think about this is to consider an infinitesimal rotation matrix, which has a simpler
form, and iterate it to get the general form. As said earlier, a rotation-direction is
given by a pair of axes. An infinitesimal rotation does nothing except take a little bit
of the vector along one axis of the pair, and gives it to the vector along the other axis.
In the (wonderful) bra-ket notation, rotating axis \\(i\\) into axis \\(j\\) is written
\\[ M = \mathbb{I} + \epsilon(|j\rangle\langle i| - |i\rangle\langle j|), \\] where
\\(\epsilon\\)
is small enough that \\(\epsilon^2\\) is negligible. We can add multiple directions together
to make new directions, but the form of the direction is going to preserve the behavior
seen above, namely that for each component \\(i\\) into \\(j\\), we have an equal and opposite
component from \\(j\\) into \\(i\\). This gives us the general form of the infinitesimal rotation
as \\(M = \mathbb{I} + \epsilon G\\) where \\(G\\) is a
[skew-symmetric matrix](http://en.wikipedia.org/wiki/Skew-symmetric_matrix). Now to
introduce the angle, let's say \\(\epsilon = \frac{\theta}{n}\\), and apply our rotator
\\(n\\)
times in a row. As we divide up the angle \(\theta\) more and more finely, we approach the
limit \\[\lim\_{n\rightarrow\infty} \left(\mathbb{I} + \frac{\theta}{n} G\right)^n\\]. You
may recognize this from discussions of compound interest as the form the the exponential
\\(e^\theta G\\). This isn't your usual exponential though, this is a *matrix exponential*,
which has a matrix in the argument, and returns a different matrix. It looks exactly the
same if you take the taylor expansion \\[e^X = \sum\_{i=0}^\infty \frac{X^n}{n!}\\]. For our
purposes we'll compute the matrix exponential only up to some finite number of powers of
\\(X\\).

Some math helpers

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


Now finally, we're ready to give the full description of rotations. We start with
\\(\binom{N}{2}\\) numbers corresponding to the weight assigned to each pair of basis vectors,
(here `components`), and construct a skew-symmetric matrix (notice there are
\\(\binom{N}{2}\\) freely varying components in such a matrix). Then the rotation matrix is
just the exponential of the angle times that matrix.

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

    rotation_matrix = (n, components, angle) ->
      return matrix_exp(angle * rotation_generator(n, components), 10)

Much as in 3D, we can apply a 'hyper-perspective' by scaling points that are far away

    apply_perspective = (pts) ->
      n = pts[0].length
      if n <= 3
        return pts
      return apply_perspective (numeric.div(p.slice(0, n-1), 3 - p[n-1]) for p in pts)

Let's set up the main function

    $(document).ready ->
      renderer = new THREE.WebGLRenderer()
      renderer.setSize WIDTH, HEIGHT

      scene = new THREE.Scene()

      camera = new THREE.PerspectiveCamera(VIEW_ANGLE, ASPECT, NEAR, FAR)
      camera.position.z = 1
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

      edges = make_edges(dim)
      lines = []
      for [i, j] in edges
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

      console.log $('#diminput')
      $('#diminput').change () ->
        console.log('here')
        n_dim = parseInt $('#diminput')[0].value
        n_axes = n_dim * (n_dim - 1) / 2
        $('#axis-container').empty()
        for i in [1..n_axes]
          $('#axis-container').append('<input type="number" value="1.0"/>')

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
        render()
      
      animate()
