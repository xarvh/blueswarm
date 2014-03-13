#
# Classes for morphogenesis of cells and body.
# by Francesco Orsenigo
#
#
# This module can translate an arbitrary string of symbols into
# an abstract shape that mocks simple life forms.
#
# As the information on the string remains coherent regardless of
# the operations performed on it, it is an optimal target for
# a genetic algorithm.
#
#
# LEXICON
#
# `morphogen`: any quantity that can influence the development of a cell.
#   The relative amounts of morphogen that a cell receives will determine
#   which parts of the genome will be executed at each developement iteration.
#
# `symbol`: An ASCII character that can appear in the genome.
#   Each symbol triggers a different effect during genome execution.
#
# `start sequence`: A combination of two symbols.
#   Once the morphogen hierarchy is determined, the genome is executed starting
#   from any point where the start sequence appears to the first stop symbol.
#


# If a generation passes this number of cells, no new cells are created.
cells_limit = 50


# Constants to scale how much a symbol expression translates
# into a cell's features
turn_factor = 5
width_factor = 1.1
height_factor = 1.1
gem_threshold = 7
generation_factor = .5


# This defines where on a cell children can gem.
stem_coordinates =
  # width coefficient, height coefficient, angle
  '<': [ +.5, .0, -90]  # left
  '^': [  .0, .5,   0]  # top
  '>': [ +.5, .0, +90]  # right


# Each different stem promoter symbol will redirect all subsequent
# code expressions towards the corresponding stem.
stem_symbols = Object.keys stem_coordinates


# 'morphogens' are a combination of stimuli that determine what gene
# sequences are activated.
#
# The relative strengths of morphogens determine which target sequence
# will be activated for the development of a cell.
# The 'generation' morphogen depends on a cell's generation, while
# 'code' morphogens are expressed by genetic code
generation_morphogen = 'g'
code_morphogens = ['n', 's', 'e', 'w']
morphogens = code_morphogens.concat [generation_morphogen]


code_promoters =
  stop: ' '
  left: 'l'
  right: 'r'
  widen: '-'
  rise: '|'


# List of all the valid symbols that can appear in a genetic code.
exports.code_symbols = code_symbols = [].concat(
  code_morphogens,
  stem_symbols,
  Object.values(code_promoters)
).sort()


# According to the hierarchy of their abundance, morphogens
# will activate different start sequences of the genome:
# each possible morphogen hierarchy permutation indicates an
# arbitrary start sequence from which to start transcription.
#
# There should be roughly as many unique target sequences
# as hierarchy permutations.
#
# With about 10 different base symbols, there are about 100
# couples of bases from which to choose from.
# This also means that a genome of about 1000 bases will contain
# many of these bases several times.
start_sequences_by_morphogen_hierarchy = make_start_sequences_by_morphogen_hierarchy code_symbols, morphogens


#
# HELPERS
#
Object.values ?= (obj) -> (v for k, v of obj)


# OpenGL deals in degrees, and so do we
#deg_sin = (angle) -> Math.sin angle * Math.PI / 180
#deg_cos = (angle) -> Math.cos angle * Math.PI / 180


permutations = (items) ->

  items = items[..]
  permutedItems = []
  itemStack = []

  recursive = ->
    for item, index in items
      items.splice(index, 1)[0]
      itemStack.push item
      if items.length is 0 then permutedItems.push itemStack[..]
      recursive items
      items.splice index, 0, item
      itemStack.pop()
    return

  recursive()
  return permutedItems


make_start_sequences_by_morphogen_hierarchy = (code_symbols, morphogens) ->

  # Start sequences are all possible combinations of code symbols, two symbols each:
  start_sequences = []
  for i in code_symbols
    for j in code_symbols
      start_sequences.push [i, j].join ''

  # Relative morphogen quantity determines a morphogen hierarchy (from most to less abundant)
  # Each possible hierarchy will in turn activate different start sequences of the genome.
  sequence_by_hierarchy = {}
  for morphogens_hierarchy, index in permutations morphogens
    # Depending on the number of symbols and morphogens, possible hierarchies may be more than
    # possible bases, which means that different hierarchies may activate the same start sequences
    sequence_by_hierarchy[morphogens_hierarchy.join ''] = start_sequences[index % start_sequences.length]

  return sequence_by_hierarchy



module.exports.Cell = class Cell
  @description: 'The basic building block of a body.'


  # this instead is used for drawing
#  square = ((-.5, -.5), (+.5, -.5), (+.5, +.5), (-.5, +.5))


  constructor: (@body, @start_sequence, @parent) ->
#    body.append(self)
    @generation = if parent then @parent.generation + 1 else 0

    # body structure
    @children = {}

    # stress values, used to animate
    @stress_angle = .0
    @stress_ratio = 1       # multiplies width, divides height
    @stress_angle_time = .0
    @stress_ratio_time = .0

    # morphogenesis steps
    @express_genome @start_sequence
    @express_to_traits()
    @express_to_stems()

    # the normalized expression values are used to determine aesthetic properties
    n = Math.max Object.values(@expression.values)...
    if n then @expression[k] /= n for k of @expression


  #
  # Express all occourrences of start_sequence in the genome.
  #
  express_genome: (start_sequence) ->

    @expression = {}
    @expression[symbol] = 0 for symbol in code_symbols

    ##@@ this dictionary generation seems to be especially slow, should be cached
    #self.stem_expression_cached.deepcopy()
    @stem_expression = {}
    for stem in stem_symbols
      @stem_expression[stem] = {}
      for morphogen in code_morphogens
        @stem_expression[stem][morphogen] = 0

    # Find targets and express all bases sequentially,
    # stopping when you find the stop marker.
    for sequence in @body.genome.split(start_sequence)[1..]
      target_stem = '^'

      for symbol in sequence

        # stem symbols change the stem to which all subsequent morphogens are applied
        if symbol in stem_symbols
          target_stem = symbol

        # morphogen symbols will increase morphogen amount in targeted stem
        else if symbol in code_morphogens
          @stem_expression[target_stem][symbol] += 1

        # count symbols occourrences
        self.expression[symbol] += 1

        # stop symbol will interrupt transcription
        if b is ' ' then break

    return


  #
  # Sets cell traits according to symbol expression.
  #
  express_to_traits: ->
    ex = @expression

    # turn
    @relax_angle = (ex['r'] - ex['l']) * @turn_factor

    # resize
    @relax_width = @width_factor ** ex['-']
    @relax_height = @height_factor ** ex['|']


  #
  # Produces new cells buds on stems
  #
  express_to_stems: ->
    for stem in stem_symbols

      sum = 0
      sum += v for k, v of @stem_expression[stem]

      if sum < gem_threshold * 1.02 ** self.generation then break

      # add generation morphogen
      # it is added only now not to interfere with the gem_threshold calculation
      @stem_expression[stem][generation_morphogen] = @generation * generation_factor

      # find hierarchy of morphogens strengths
      hierarchy = ({k, v} for k, v of @stem_expression[stem])
        .sort((a, b) -> a.v - b.v)
        .map((o) -> o.k)
        .join ''

      # translate hierarchy into a target sequence
      start_sequence = start_sequences_by_morphogen_hierarchy[hierarchy]

      # mark the stem for spawning
      @children[stem] = start_sequence

    return


    #
    # Create a new cell at a stem point.
    #
    gem: ->
      cnt = 0

      for stem in stem_symbols when start_sequence = @children[stem]
        @children[stem] = new Cell @body, start_sequence, this
        cnt += 1

      return cnt


#    def recursive_set_coordinates(self, x=.0, y=.0, stem_angle=.0):
#        """ """
#        # update width and height
#        self.width = self.relax_width * self.stress_ratio
#        self.height = self.relax_height / self.stress_ratio
#
#        # resulting angle depends on all previous angles
#        self.angle = math.fmod(stem_angle + self.relax_angle + self.stress_angle, 360)
#
#        # the cell is attached by its bottom side
#        # thus the center is displaced by the cell's height
#        self.cx = x + deg_sin(self.angle) * self.height/2
#        self.cy = y + deg_cos(self.angle) * self.height/2
#
#
#        # update children
#        for s in self.stem_symbols:
#            child = self.children[s]
#            if child:
#                wf, hf, a = self.stem_coordinates[s]
#
#                # calculate stem angle
#                sa = self.angle + a
#
#                # calculate stem position
#                l = wf*self.width + hf*self.height
#                sx = self.cx + l*deg_sin(sa)
#                sy = self.cy + l*deg_cos(sa)
#
#                # update child
#                child.recursive_set_coordinates(sx, sy, sa)
#
#
#
#    def animate(self):
#        """ """
#        if not self.parent:
#            return
#
#        # stress angle
#        self.stress_angle_time = (self.stress_angle_time + 10*self.expression['s']) % 360
#        self.stress_angle = deg_sin(self.stress_angle_time) * 10*self.expression['n']
#
#        # stress ratio
#        self.stress_ratio_time = (self.stress_ratio_time + 10*self.expression['e']) % 360
#        self.stress_ratio = 1.3 ** deg_sin(self.stress_ratio_time)
#
#
#
#
#
#    def draw(self):
#        """ """
#        # isolate matrix operations
#        glPushMatrix()
#
#        glTranslated(self.cx, self.cy, 0)
#        glRotated(self.angle, 0, 0, -1)
#        glScaled(self.width, self.height, 1)
#
#        # solid cell body
#        e = self.expression
#        glColor4f(e[' ']/3, e['|']/2, .5+e['^']/2, .8)
#        glEnable(GL_BLEND)
#        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
#        glBegin(GL_QUADS)
#        for v in self.square:
#            glVertex2f(*v)
#        glEnd()
#
#        # contour
#        glBegin(GL_LINE_LOOP)
#        glColor4f(0, 0, 1, .9)
#        for v in self.square:
#            glVertex2f(*v)
#        glEnd()
#
#        glPopMatrix()




#
# A clump of cells sharing the same genetic material.
#
module.exports.Body = class Body

    constructor: (@genome) ->

      # start body with strongest target sequence
      best = ''
      best_count = 0
      for hi, seq of start_sequences_by_morphogen_hierarchy
        count = @genome.match(new RegExp seq, 'g').length
        if count > best_count then [best, best_count] = [seq, count]


      # generate body
      @cells = []
      @root = new Cell this, best
      new_cells = 1
      last_generation = @root.generation
      while new_cells > 0 and @cells.length < cells_limit
        new_cells = 0
        for cell in self when cell.generation is last_generation
          new_cells += cell.gem()
        last_generation += 1

      # clean up
      for cell in @cells
        for stem, child of cell.children when typeof child is 'string'
          delete cell.children[stem]

      # shape body
      @scale = null
#      @update_coordinates()



#    # recalculates cell tree geometry
#    def update_coordinates(self):
#        """ """
#        self.root.recursive_set_coordinates()
#
#
#
#
#
#
#    def update(self):
#        """
#        Executes a whole time iteration.
#
#        """
#        for c in self:
#            c.animate()
#
#        self.update_coordinates()
#
#
#
#    def draw(self):
#        """ """
#        x = [c.cx for c in self]
#        y = [c.cy for c in self]
#        ox = (max(x)+min(x)) /2
#        oy = (max(y)+min(y)) /2
#
#        if not self.scale:
#            w = max(x)-min(x)
#            h = max(y)-min(y)
#            self.scale = 2./max(w, h, self.root.width)
#
#        glPushMatrix()
#        glScaled(self.scale, self.scale, 1)
#        glTranslated(-ox, -oy, 0)
#        for c in self:
#            c.draw()
#        glPopMatrix()
#
#
#
#
#if __name__ == '__main__':
#    print 'morphogens: ', Cell.morphogens
#    print 'promoters:', Cell.code_promoters.values()
#    print 'stems:', Cell.stem_symbols
#
#EOF

