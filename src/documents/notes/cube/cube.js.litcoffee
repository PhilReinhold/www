# Hypercubes in CoffeeScript and WebGL

A cube is a simple thing. The most natural definition is recursive.  A line is
two points, separated and connected.  A square is two lines, separated, and
connected pointwise.  An N-cube is a pair of (N-1)-cubes, separated in the new
N-th dimension, with edges strung together so that the k-th point on the first
(N-1)-cube is connected to the k-th point of the second.

    class n_cube
      constructor: (@n) ->
        if n == 0
          @vertices = [[]]
          @edges = []
          @faces = []
          return

        sub_cube_1 = new n_cube(@n - 1)
        sub_cube_2 = new n_cube(@n - 1)

        sub_cube_1.extend_dimension(-1)
        sub_cube_2.extend_dimension(1)

        @vertices = sub_cube_1.vertices.concat sub_cube_2.vertices

        # An edge is just an index into the vertices list
        n = sub_cube_1.vertices.length
        @edges = sub_cube_1.edges.concat ([i+n, j+n] for [i, j] in sub_cube_2.edges)
        new_edges = _.zip([0..n-1], [n..2*n-1])
        @edges = @edges.concat new_edges

        @faces = sub_cube_1.faces.concat sub_cube_2.faces
        @faces += ([new_edges[i],new_edges[i+1]] for i in [0..new_edges.length-2])

      extend_dimension: (z) ->
        v.push z for v in @vertices

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

    matrix_exp = (mat, n) ->
      ret = numeric.identity mat.length
      mat_acc = numeric.identity mat.length
      for i in [1..n]
        mat_acc = numeric.dot mat_acc, mat
        ret = numeric.add(ret, numeric.mul((1.0 / fact(i)), mat_acc))
      return ret

    fact = _.memoize (n) ->
      if n <= 1
        return 1
      else
        return n * fact(n - 1)

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
      return matrix_exp(numeric.mul(angle, rotation_generator(n, components)), 10)

Much as in 3D, we can apply a 'hyper-perspective' by scaling points that are far away

    apply_perspective = (pts) ->
      n = pts[0].length
      if n <= 3
        return pts
      return apply_perspective (numeric.div(p.slice(0, n-1), 3 - p[n-1]) for p in pts)

Finally, let's set up WebGL using [three.js](http://threejs.org). The initial setup is
pretty standard.

    class hypercube_demo
      constructor: ->
        WIDTH = 400
        HEIGHT = 300
        VIEW_ANGLE = 45
        ASPECT = WIDTH / HEIGHT
        NEAR = 0.1
        FAR = 10000

        @renderer = new THREE.WebGLRenderer()
        @renderer.setSize WIDTH, HEIGHT

        @scene = new THREE.Scene()

        @camera = new THREE.PerspectiveCamera VIEW_ANGLE, ASPECT, NEAR, FAR
        @camera.position.z = 3
        @scene.add @camera

        light = new THREE.PointLight 0xFFFFFF
        light.position.set 10, 50, 130
        @scene.add light
        $('#scene-container').append @renderer.domElement

        @set_dimension(4)

Since I want to use [numeric.js](http://numericjs.com) to handle the matrix math,
I need to keep synchronized copies of the cube vertex positions. One as a standard JS
array (for numeric) which has the full dimension, and another as a three.js vector with
three components for rendering.
      
      set_dimension: (n) ->
        @cube = new n_cube n
        @n_rotations = n * (n-1) / 2
        @display_vertices =
          (new THREE.Vector3(v) for v in (apply_perspective @cube.vertices))
        @display_edges =
          (new simple_line (@display_vertices[i] for i in e) for e in @cube.edges)

        @scene.remove e for e in @scene.children # Clear the scene
        @scene.add e for e in @display_edges
        console.log @scene
        console.log @display_edges
        console.log @cube.edges

The interface provides a way of selecting which of the \\(\binom{N}{2}\\) axes to rotate
along. When the dimension, changes, the number of axes changes too.

        $('#currentdim').text(n.toString())
        $('#axis-container').empty()
        for i in [1..@n_rotations]
          $('#axis-container').append("<input type=checkbox id=axis#{i}>#{i}</input>")
          $("#axis#{i}").click(=> @update_rotator())

        @update_rotator()

      update_rotator: ->
        console.log @
        components =
          ((if axis.checked then 1 else 0) for axis in $('#axis-container').children().toArray())
        @rotator = rotation_matrix(@cube.n, components, .01)
        console.log @rotator

      rotate: ->
        @cube.vertices = (numeric.dot(@rotator, v) for v in @cube.vertices)

        for [[x, y, z], dv] in _.zip (apply_perspective @cube.vertices), @display_vertices
          dv.set(x, y, z)

        for line in @display_edges
          line.geometry.verticesNeedUpdate = true


    simple_line = (points) ->
      console.log(points)
      geometry = new THREE.Geometry()
      geometry.vertices.push(p) for p in points
      return new THREE.Line geometry

    $(document).ready ->
      demo = new hypercube_demo

      animate = ->
        requestAnimationFrame animate
        if $('#updatecheck')[0].checked
          demo.rotate()
        demo.renderer.render(demo.scene, demo.camera)

      animate()
