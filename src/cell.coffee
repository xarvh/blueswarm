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

#TODO: don't mess with natives...
Object.values ?= (obj) -> (v for k, v of obj)

{PI, sin, cos} = Math
ROUND_ANGLE = PI * 2


# If a generation passes this number of cells, no new cells are created.
CELLS_LIMIT = 50


# Constants to scale how much a symbol expression translates
# into a cell's features
TURN_FACTOR = 5
WIDTH_FACTOR = 1.1
HEIGHT_FACTOR = 1.1
GEM_THRESHOLD = 7
GENERATION_FACTOR = .5


# This defines where on a cell children can gem.
STEM_COORDINATES =
  # width coefficient, height coefficient, angle
  '<': [ +.5, .0, -90]  # left
  '^': [  .0, .5,   0]  # top
  '>': [ +.5, .0, +90]  # right


# Each different stem promoter symbol will redirect all subsequent
# code expressions towards the corresponding stem.
STEM_SYMBOLS = Object.keys STEM_COORDINATES


# 'morphogens' are a combination of stimuli that determine what gene
# sequences are activated.
#
# The relative strengths of morphogens determine which target sequence
# will be activated for the development of a cell.
# The 'generation' morphogen depends on a cell's generation, while
# 'code' morphogens are expressed by genetic code
GENERATION_MORPHOGEN = 'g'
CODE_MORPHOGENS = ['n', 's', 'e', 'w']
MORPHOGENS = CODE_MORPHOGENS.concat [GENERATION_MORPHOGEN]


CODE_PROMOTERS =
  stop: ' '
  left: 'l'
  right: 'r'
  widen: '-'
  rise: '|'


# List of all the valid symbols that can appear in a genetic code.
module.exports.CODE_SYMBOLS = CODE_SYMBOLS = [].concat(
  CODE_MORPHOGENS,
  STEM_SYMBOLS,
  Object.values(CODE_PROMOTERS)
).sort()


#
# HELPERS
#
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


make_start_sequences_by_morphogen_hierarchy = ->

  # Start sequences are all possible combinations of code symbols, two symbols each:
  start_sequences = []
  for i in CODE_SYMBOLS
    for j in CODE_SYMBOLS
      start_sequences.push [i, j].join ''

  # Relative morphogen quantity determines a morphogen hierarchy (from most to less abundant)
  # Each possible hierarchy will in turn activate different start sequences of the genome.
  sequence_by_hierarchy = {}
  for morphogens_hierarchy, index in permutations MORPHOGENS
    # Depending on the number of symbols and morphogens, possible hierarchies may be more than
    # possible bases, which means that different hierarchies may activate the same start sequences
    sequence_by_hierarchy[morphogens_hierarchy.join ''] = start_sequences[index % start_sequences.length]

  return sequence_by_hierarchy


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
start_sequences_by_morphogen_hierarchy = make_start_sequences_by_morphogen_hierarchy()


#
# CELL
#
module.exports.Cell = class Cell
  @description: 'The basic building block of a body.'


  constructor: (@body, @start_sequence, @parent) ->
    @body.cells.push this
    @generation = if @parent then @parent.generation + 1 else 0

    # body structure
    @children = {}

    # stress values, used to animate
    @stress_angle = 0
    @stress_ratio = 1       # multiplies width, divides height
    @stress_angle_time = 0
    @stress_ratio_time = 0

    # morphogenesis steps
    @express_genome @start_sequence
    @express_to_traits()
    @express_to_stems()

    # the normalized expression values are used to determine aesthetic properties
    n = Math.max Object.values(@expression)...
    if n then @expression[k] /= n for k of @expression


  #
  # Express all occourrences of start_sequence in the genome.
  #
  express_genome: (start_sequence) ->

    @expression = {}
    @expression[symbol] = 0 for symbol in CODE_SYMBOLS

    # TODO: this dictionary generation seems to be especially slow, should be cached
    # @stem_expression_cached.deepcopy()
    @stem_expression = {}
    for stem in STEM_SYMBOLS
      @stem_expression[stem] = {}
      for morphogen in CODE_MORPHOGENS
        @stem_expression[stem][morphogen] = 0

    # Find targets and express all bases sequentially,
    # stopping when you find the stop marker.
    for sequence in @body.genome.split(start_sequence)[1..]
      target_stem = '^'

      for symbol in sequence

        # stem symbols change the stem to which all subsequent morphogens are applied
        if symbol in STEM_SYMBOLS
          target_stem = symbol

        # morphogen symbols will increase morphogen amount in targeted stem
        else if symbol in CODE_MORPHOGENS
          @stem_expression[target_stem][symbol] += 1

        # count symbols occourrences
        @expression[symbol] += 1

        # stop symbol will interrupt transcription
        if symbol is ' ' then break

    return


  #
  # Sets cell traits according to symbol expression.
  #
  express_to_traits: ->
    ex = @expression

    # turn
    @relax_angle = (ex['r'] - ex['l']) * TURN_FACTOR

    # resize
    @relax_width = WIDTH_FACTOR ** ex['-']
    @relax_height = HEIGHT_FACTOR ** ex['|']


  #
  # Produces new cells buds on stems
  #
  express_to_stems: ->
    for stem in STEM_SYMBOLS

      sum = 0
      sum += v for k, v of @stem_expression[stem]

      if sum < GEM_THRESHOLD * 1.02 ** @generation then break

      # add generation morphogen
      # it is added only now not to interfere with the GEM_THRESHOLD calculation
      @stem_expression[stem][GENERATION_MORPHOGEN] = @generation * GENERATION_FACTOR

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

    for stem in STEM_SYMBOLS when start_sequence = @children[stem]
      @children[stem] = new Cell @body, start_sequence, this
      cnt += 1

    return cnt


  #
  # Geometry
  #
  recursive_set_coordinates: (x = .0, y = .0, stem_angle = .0) ->
    # update width and height
    @width = @relax_width * @stress_ratio
    @height = @relax_height / @stress_ratio

    # resulting angle depends on all previous angles
    @angle = (stem_angle + @relax_angle + @stress_angle) % ROUND_ANGLE

    # the cell is attached by its bottom side
    # thus the center is displaced by the cell's height
    @cx = x + sin(@angle) * @height / 2
    @cy = y + cos(@angle) * @height / 2

    # update children
    for symbol, child of @children
      [wf, hf, a] = STEM_COORDINATES[symbol]

      # calculate stem angle
      sa = @angle + a

      # calculate stem position
      l = wf * @width + hf * @height
      sx = @cx + l * sin sa
      sy = @cy + l * cos sa

      # update child
      child.recursive_set_coordinates sx, sy, sa

    return


  animate: (deltaTime) ->
    if !@parent then return

    # stress angle
    @stress_angle_time = (@stress_angle_time + deltaTime*@expression['s']) % ROUND_ANGLE
    @stress_angle = 0.17 * sin(@stress_angle_time) * @expression['n']

    # stress ratio
    @stress_ratio_time = (@stress_ratio_time + deltaTime*@expression['e']) % ROUND_ANGLE
    @stress_ratio = 1.3 ** sin @stress_ratio_time


#
# A clump of cells sharing the same genetic material.
#
module.exports.Body = class Body

  constructor: (@genome) ->

    # start body with strongest target sequence
    best = ''
    best_count = 0
    for hi, seq of start_sequences_by_morphogen_hierarchy
      count = @genome.match(new RegExp seq, 'g')?.length
      if count > best_count then [best, best_count] = [seq, count]


    # generate body
    @cells = []
    @root = new Cell this, best
    new_cells = 1
    last_generation = @root.generation
    while new_cells > 0 and @cells.length < CELLS_LIMIT
      new_cells = 0
      for cell in @cells when cell.generation is last_generation
        new_cells += cell.gem()
      last_generation += 1

    # clean up
    for cell in @cells
      for stem, child of cell.children when typeof child is 'string'
        delete cell.children[stem]

    # shape body
    @scale = null


  animate: (deltaTime) ->
    c.animate deltaTime for c in @cells
    @root.recursive_set_coordinates()


#if __name__ == '__main__':
#    print 'morphogens: ', Cell.morphogens
#    print 'promoters:', Cell.CODE_PROMOTERS.values()
#    print 'stems:', Cell.STEM_SYMBOLS
#
#EOF

