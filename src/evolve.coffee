#
# Genetic algorithm class
# by Francesco Orsenigo
#
randomChoice = (array) -> array[Math.floor Math.random() * array.length]


#
# `population` must be a hash where each key is a genome string and
# the corresponding value is the fitness value for that genome.
#
module.exports.Evolution = class Evolution


  @makeRandomGenome = (symbols, length = 2) ->
    (randomChoice symbols for [1..length]).join ''


  @createRandomPop = (genome_symbols, genome_length, pop_size = 100) ->
    pop = {}
    pop[Evolution.makeRandomGenome genome_symbols, genome_length] = 0 for [1..pop_size]
    return pop


  @pickFitParent = (population) ->

    totalFitness = 0
    totalFitness += fitness for genome, fitness of population

    # Random choice weighted on fitness
    r = Math.random() * totalFitness
    for genome, fitness of population
      r -= fitness
      if r <= 0 then return genome

    throw ''


  @newGenomeFromPopulation = (population, genome_symbols, break_symbol, mutationChance = 0.01) ->

    # Recombine from two parents:
    son = []
    for [1..2]
      blocks = Evolution.pick_fit_parent(population).split break_symbol
      son.push randomChoice blocks for [1..(Math.max 1, blocks.length / 2)]

    genome = son.join break_symbol

    # Add random errors
    lc = genome.split ''

    # The correct way to do this would be to iterate random
    # on every symbol of genome, but it would be too slow and
    # probably not that random.
    # So I will just invoke the Law of Big Numbers and
    # assume that the actual number of mutations matches
    # exactly its expected value.
    mutations_count = Math.max 1, genome.length * mutationChance
    for [1..mutations_count]
      lc[Math.floor lc.length * Math.random()] = randomChoice genome_symbols

    return lc.join ''


  @reduceFitnessForLargeGenomes = (population, fitnessBase = 0.8) ->

    lengths = (genome.length for genome of population)
    fitness = (fitness for genome, fitness of population)

    # normalization factors
    fMax = Math.max fitness...
    fMin = Math.min fitness...
    fd = 1 / (fMax - fMin or 1)
    ld = 1 / Math.max lengths...

    for genome, fitness of population
      population[genome] = (fitness - fMin) * fd * fitnessBase ** (genome.length * ld)

    return


  @speciate = (population) ->
    newPopulation = {}
    genomes = Object.keys population

    # Randomly get half of a population's genomes...
    for [1..genomes.length / 2]
      genome = randomChoice genomes

      # ...and move them to a new population
      delete population[genome]
      newPopulation[genome] = 0

    return newPopulation

