#
# Genetic algorithm class
# by Francesco Orsenigo
#
#
# Carries the evolution iteration of a population, according to the given
# fitness function.
#
sum = (array) -> array.reduce ((sum, v) -> sum + v), 0


randomChoice = (array) -> array[Math.floor Math.random() * array.length]


module.exports.Evolution = class Evolution


  @makeRandomGenome = (symbols, length = 2) ->
    (randomChoice symbols for [1..length]).join ''


  @create_initial_pop = (genome_symbols, genome_length, pop_size = 100) ->
    (@makeRandomGenome genome_symbols, genome_length for [1..pop_size])


  constructor: (@fitness_function, @genome_symbols, @break_symbol, initial_pop) ->
    @pop = initial_pop ? Evolution.create_initial_pop @genome_symbols
    @fitness = @pop.map -> 0
    @generation = 0


  test_pop: ->
    base_fit = @pop.map @fitness_function

    # TODO: code length fitness should be evaluated inside @fitness_function
    #
    # code length does affect fitness, but it is easier
    # to factor that in here rather than within the fitness_function
    lengths = @pop.map (p) -> p.length

    # normalization factors
    Fma = Math.max base_fit...
    Fmi = Math.min base_fit...
    fd = 1 / (Fma-Fmi or 1)
    ld = 1 / Math.max lengths...

    # update
    @fitness = lengths.map (length, index) -> (base_fit[index] - Fmi) * fd * 0.8 ** (length*ld)


  pick_fit_parent: ->
    # random choice weigthed on fitness
    r = Math.random() * sum @fitness
    for code, index in @pop
      r -= @fitness[index]
      if r <= 0 then return code

    return randomChoice @pop


  recombine_from_parents: (parents_cnt = 2) ->
    son = []

    for [1..parents_cnt]
      blocks = @pick_fit_parent().split @break_symbol
      son.push randomChoice blocks for [1 .. (Math.max 1, blocks.length / parents_cnt)]

    # duplicate blocks, lose blocks
#        if random.random() < .002:
#            son.pop(random.randrange(len(son)))
#        if random.random() < .002:
#            son.append(random.choice(son))

    return son.join @break_symbol


  add_random_errors: (genome, mutation_chance = 0.01) ->
    # The correct way to do this would be to iterate random
    # on every symbol of genome, but it would be too slow and
    # probably not that random.
    # So I will just invoke the Law of Big Numbers and
    # assume that the actual number of mutations matches
    # exactly its expected value.

    lc = genome.split ''
    mutations_count = Math.max 1, genome.length * mutation_chance

    for [1..mutations_count]
      lc[Math.floor lc.length * Math.random()] = randomChoice @genome_symbols

    return lc.join ''


  next_generation: ->

    @test_pop()

    # new generation
    @pop = @pop.map -> @add_random_errors @recombine_from_parents()
    @generation += 1

