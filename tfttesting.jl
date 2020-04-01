# TFT combat simulator (C) 2018, Bill Burdick
#
# Original C/AL code by Nils Lindeberg, Aug 17, 2018 (in a different file)
# Translated to Julia and modified by Bill Burdick, Oct 28, 2018

# TODO replace many old ints with booleans
# TODO add cmdline option for defend-against-charge

using Profile

struct Weapon
    id::Int
    name::String
    minimumst::Int
    dice::Int
    mod::Int
    polearm::Int
    twohanded::Int
    extraattacks::Int
    dxpenaltyallattacks::Int
    dxpenaltysecondaryattack::Int
    thrown::Int
    Weapon(id, name) = new(id, name, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    Weapon(id, name, st, dice, mod) = new(id, name, st, dice, mod, 0, 0, 0, 0, 0, 0)
    function Weapon(w::Weapon; id=w.id, name=w.name, minimumst=w.minimumst, dice=w.dice, mod=w.mod, mods...)
        Weapon(id, name, minimumst, dice, mod; mods...)
    end
    function Weapon(id, name, st, dice, mod; polearm=0, twoh=0, extraatks=0, dxpenaltyall=0, dxpenaltysecondary=0, thrown=0)
        new(id, name, st, dice, mod, polearm, twoh, extraatks, dxpenaltyall, dxpenaltysecondary, thrown)
    end
    function Weapon(id, name, st, dice, mod, polearm, twoh, extratks, dxpenaltyall, dxpenaltysecondary, thrown)
        new(id, name, st, dice, mod, polearm, twoh, extratks, dxpenaltyall, dxpenaltysecondary, thrown)
    end
end

struct Armor
    id::Int
    armornamecombo::String
    armor::Int
    shield::Int
    dxpenalty::Int
    Armor(armor) = Armor(armor.id, armor.armornamecombo, armor.armor, armor.shield)
    Armor(armor, penalty) = Armor(armor.id, armor.armornamecombo, armor.armor, armor.shield, penalty)
    Armor(id, name, value, shield) = Armor(id, name, value, shield, value + max(0, shield - 1))
    Armor(id, name, value, shield, penalty) = new(id, name, value, shield, penalty)
end

mutable struct Warrior
    id::Int
    name::String
    st::Int
    dx::Int
    iq::Int
    adjdx::Int
    weapon::Weapon
    armor::Int
    armordata::Armor
    enemyadjdx::Int
    expert::Int
    master::Int
    shrewd::Int
    uclevel::Int
    numberofhits::Int
    numberofstrikes::Int
    numberofcharges::Int
    numberofmatches::Int
    damagedone::Int
    damagetaken::Int
    armorabsorbed::Int
    numberofwins::Int
    numberofturns::Int
    nemesislosses::Int
    nemesisofhowmany::Int
    nemesis

    function Warrior(w::Warrior; name=w.name, st=w.st, dx=w.dx, iq=w.iq, weapon=w.weapon, armor=w.armor, armordata=w.armordata, enemyadjdx=w.enemyadjdx, expert=w.expert, master=w.master, shrewd=w.shrewd, uclevel=w.uclevel, id=w.id)
        Warrior(id, name, st, dx, iq, weapon, armor, armordata, enemyadjdx, expert, master, shrewd, uclevel)
    end
    function Warrior(id, name, st, dx, iq, weapon, armor, armordata, enemyadjdx, expert, master, shrewd, uclevel)
        adjdx = dx - armordata.dxpenalty - weapon.dxpenaltyallattacks
        new(id, name, st, dx, iq, adjdx, weapon, armor, armordata, enemyadjdx, expert, master, shrewd, uclevel, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, nothing)
    end
end

winrate(w) = w.numberofmatches > 0 ? w.numberofwins / w.numberofmatches : 0
avghitspermatch(w) =  w.numberofmatches > 0 ? w.numberofhits / w.numberofmatches : 0
avgdmgdealtpermatch(w) = w.numberofmatches > 0 ? w.damagedone / w.numberofmatches : 0
avgdmgtakenpermatch(w) = w.numberofmatches > 0 ? w.damagetaken / w.numberofmatches : 0
avgturnspermatch(w) = w.numberofmatches > 0 ? w.numberofturns / w.numberofmatches : 0
avgstrikesperturn(w) = w.numberofturns > 0 ? w.numberofstrikes / w.numberofturns : 0
avgchargesperturn(w) = w.numberofturns > 0 ? w.numberofcharges / w.numberofturns : 0
avgdmgperhit(w) = w.numberofhits > 0 ? w.damagedone / w.numberofhits : 0
avgarmorabspermatch(w) = w.numberofmatches > 0 ? w.armorabsorbed / w.numberofmatches : 0
armorname(w) = w.armordata.armornamecombo
weaponname(w) = w.weapon.name
weapondice(w) = w.weapon.dice
weaponmod(w) = w.weapon.mod
extraattacks(w) = w.weapon.extraattacks
polearm(w) = w.weapon.polearm
nemesisid(w) = w.nemesis == nothing ? "" : w.nemesis.id
nemesisname(w) = w.nemesis == nothing ? "" : w.nemesis.name
twohanded(w) = w.weapon.twohanded
dxpenaltysecondaryattack(w) = w.weapon.dxpenaltysecondaryattack

outputfields = (
    id="ID",
    winrate="Win Rate",
    avghitspermatch="Avg Hits Per Match",
    avgdmgdealtpermatch="Avg Dmg Delt Per Match",
    avgdmgtakenpermatch="Avg Dmg Taken Per Match",
    avgturnspermatch="Avg Turns Per Match",
    avgstrikesperturn="Avg Strikes Per Turn",
    avgchargesperturn="Avg Charges Per Turn",
    avgdmgperhit="Avg Dmg per Hit",
    avgarmorabspermatch="Avg Armor Abs Per Match",
    name="Name",
    st="ST",
    dx="DX",
    iq="IQ",
    adjdx="adjDX",
    armor="A",
    enemyadjdx="Enemy Adj DX",
    armorname="Armor Name",
    weaponname="Weapon Name",
    weapondice="Weapon Dice",
    weaponmod="Weapon Mod",
    extraattacks="Extra Attacks",
    dxpenaltysecondaryattack="DX Penalty Second Attack",
    polearm="Pole Arm",
    uclevel="UC Level",
    numberofhits="Number of Hits",
    numberofstrikes="Number of Strikes",
    numberofcharges="Number of Charges",
    damagedone="Damage Done",
    numberofmatches="Number of Matches",
    damagetaken="Damage Taken",
    armorabsorbed="Armor Absorbed",
    numberofwins="Number of Wins",
    numberofturns="Number of Turns",
    expert="Expert",
    master="Master",
    shrewd="Shrewd",
    nemesisname="Nemesis Name",
    nemesisid="Nemesis",
    nemesislosses="Nemesis Losses",
    nemesisofhowmany="Nemesis of How Many"
)

getwarriorproperty(w, k::Symbol) = k in fieldnames(Warrior) ? getfield(w, k) : getfield(Main, k)(w)

mutable struct WarriorState
    warrior::Warrior         #
                             # gP1[1]: warrior.st
                             # gP1[3]: warrior.dx
                             # gP1[4]: warrior.adjdx
                             # gP1[5]: warrior.armor
                             # gP1[6]: warrior.weapondice
                             # gP1[7]: warrior.weaponmod
                             # gP1[9]: warrior.polearm
                             # gP1[18]: warrior.enemyadjdx
                             # gP1[20]: warrior.shrewd
                             # gP1[21]: warrior.weapon.extraattacks
                             # gP1[22]: warrior.weapon.dxpenaltysecondaryattack
                             # gP1[23]: warrior.uclevel
    curst::Int               # gP1[2]
    tmpdxmod::Int            # gP1[8]
    chargechance::Int        # gP1[10]
    fallen::Int              # gP1[11]
    lastattackdamaged::Int   # gP1[12]
    numberofhits::Int        # gP1[13]
    damagedone::Int          # gP1[14]
    setvschargebonus::Int    # gP1[15]
    damagetaken::Int         # gP1[16]
    armorabsorbed::Int       # gP1[17]
    weaponmastry::Int        # gP1[19]: 0, 1 = Expert, 2 = Master, 3 = Fencer Expert, 4 = Fencer Master
    function WarriorState(warrior)
        mastry = warrior.expert + 2 * warrior.master
        if mastry > 0 && warrior.weapon.name in ["Rapier", "Cutlass"]
            mastry += 2
        end
        new(warrior, warrior.st, 0, warrior.weapon.polearm * (Gsettings.new3hexcharge ? Gsettings.initialchargechance : 100), 0, 0, 0, 0, 0, 0, 0, mastry)
    end
end

protection(armor::Armor) = armor.armor + armor.shield

Gwarriors = []
Gpairs = Dict{Warrior, Warrior}()
pushwarrior(w::Warrior) = push!(Gwarriors, w)
Gwarriorkeys = Set([:name :st :dx :iq :weapon :armor :armordata :enemyadjdx :expert :master :shrewd :uclevel :expertisedxadj :adjdx])

Gweapontable = [
    Weapon(1, "Dagger", 8, 1, -1, thrown=1)
    Weapon(2, "Rapier", 9, 1, 0)
    Weapon(3, "Javelin", 9, 1, -1, polearm=1, thrown=1)
    Weapon(4, "Cutlass", 10, 2, -2)
    Weapon(5, "Hatchet", 9, 1, 0, thrown=1)
    Weapon(6, "Spear 1H", 11, 1, 0, polearm=1, thrown=1) # see adjweapontable
    Weapon(7, "Spear 2H", 11, 1, 1, polearm=1, thrown=1, twoh=1) # see adjweapontable
    Weapon(8, "Mace", 11, 2, -1, thrown=1)
    Weapon(9, "Broadsword", 12, 2, 0)
    Weapon(10, "Bastard Sword 2H", 13, 3, -2, twoh=1)
    Weapon(11, "Halberd", 13, 2, 0, polearm=1, twoh=1)
    Weapon(12, "Morningstar", 13, 2, 1)
    Weapon(13, "2-handed Sword", 14, 3, -1, twoh=1)
    Weapon(14, "Pike Ax", 15, 2, 2, polearm=1, twoh=1)
    Weapon(15, "Battle Axe", 15, 3, 0, twoh=1)
    Weapon(16, "Great Sword", 16, 3, 1, twoh=1)
    Weapon(17, "Double Nunchuks", 9, 1, -1, twoh=1, extraatks=1, dxpenaltyall=4)
]
Gweaponsbyname = Dict([weapon.name => weapon for weapon in Gweapontable])

makeflorentine(weaponname; mods...) = Weapon(Gweaponsbyname[weaponname]; id=length(Gweapontable) + 1, extraatks=1, dxpenaltysecondary=4, mods...)

Gucweapons = Dict()
Garmortable = [
    Armor(1, "No Armor", 0, 0)
    Armor(2, "No Armor, Small Shield", 0, 1)
    Armor(3, "No Armor, Large Shield", 0, 2)
    Armor(4, "No Armor, Tower Shield", 0, 3)
    Armor(5, "Cloth", 1, 0)
    Armor(6, "Cloth, Tower Shield", 1, 3)
    Armor(7, "Leather", 2, 0)
    Armor(8, "Leather, Tower Shield", 2, 3)
    Armor(9, "Chainmail", 3, 0)
    Armor(10, "Chainmail, Tower Shield", 3, 3)
    Armor(11, "Half-Plate", 4, 0)
    Armor(12, "Plate", 5, 0)
    Armor(13, "Plate, Large Shield", 5, 2)
    Armor(14, "Plate, Tower Shield", 5, 3)
]
Garmorbyname = Dict([armor.armornamecombo => armor for armor in Garmortable])
noarmor() = Garmortable[1]
smshield() = Garmortable[2]
clotharmor() = Garmortable[5]
Gbarehanddamage = cat([[(range.start, dice, mod) for i in range] for (range, (dice, mod)) in [
    1:8=>(1,-4)
    9:10=>(1,-3)
    11:12=>(1,-2)
    13:14=>(1,-1)
    15:16=>(1,0)
    17:20=>(1,1)
    21:24=>(1,2)
    25:30=>(1,3)
    31:40=>(2,1)
    41:50=>(3,1)
    51:60=>(4,1)
]]..., dims=1)
Gucevadepenalty = [0, 1, 2, 2, 2]
Gucevadeprotection = [0, 1, 2, 2, 3]
Gwin1 = 0
Gwin2 = 0
Gdraw = 0
Gstatforcedretreats = 0
Gstatnumberofcharges = 0
Gstatnumberofattacksonprone = 0
Gstatavgtohitp1 = 0
Gstatavgtohitp2 = 0
Gstatavgnumberofturns = 0
Gnumberofdisengages = 0
Gtotalturns = 0
Gnemesis = []
okst = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17]
reptilest = [12, 13, 15, 17, 21]
Gsettings = (
    newrules = false,
    #numberofmatches = 3,
    numberofmatches = 15,
    debug = false,
    new3hexcharge = true,       # +2 for set vs charge, 50/50 if you get a charge.
    setvschargechance = 50,     # If FALSE old vanilla rule, all charges 100 and all get +2.
    twohexchargechance = 75,    # IF MA 10 - enemy must charge if you win, otherwise jab.
    onehexchargechance = 50,    # IF MA > 10
    initialchargechance = 75,   # You almost always get a charge, but not always a set vs. charge.
    newarmors = true,           # flat armor progression.
    nopolearmdouble = true,     # Instead of x2 damage, pole arms get +1d6.
    minimum1dmg = false,
    defending = false,          # Defend when opponents gets a charge. Chargers gets first strike so defender never goes first.
                                # Defend only when you have higher DX. Othwerwise pole armed opponent will disengage.
    disengaging = true,
    dxdifdisengage = true,
    newpoleweapons = false,
    minadjdx = 7,               # 0 = Allow all. 7 Scrap all builds below 7.
    maxadjdx = 20,              # With a lot of experts and mastery around and shrewd attacks of your own...
    uc = true,
    florentine = true,
    isbrawlingstacking = false, # Do UC stack with Brawling damage?
    expertise = true,           # If adjDX 14+ THEN adjDX -2(IQ) and +1/-1.
                                # Expertise talent allowed. Min IQ 10, DX 12 +1dmg
                                # -1 enemy tohit, (+1d6/-5DX. When?) Shrewd.
                                # Fencer -4DX. Only dagger,rapier,cutlass. Shrewd.
                                # Shield IQ? -1DX enemy, +1Armor.
    talents = false,            # Warrior IQ10 ST14, Veteran IQ10 ST16. Only good after Weapon Expert or max armor.
                                # Since we don't take MA into account.
    points = 40,
    monster = false,
    maxnumberofturns = 30,
    reptiles = false,
)
Gmatcher = zeros(Int, Gsettings.numberofmatches)
Gprofile = false

function setglobals(ARGS)
    points = 40
    orig = false
    i = 1
    while i <= length(ARGS)
        arg = ARGS[i]
        i += 1
        if arg == "-points"
            points = parse(Int, ARGS[i])
            println(stderr, "SET POINTS TO ", points)
            i += 1
        elseif arg == "-orig"
            orig = true
        elseif arg == "-prof"
            global Gprofile = true
        end
    end

    if orig
        global Gsettings = (Gsettings..., points=points)
    else
        global Gsettings = (
            Gsettings...,
            points = points,
            newrules = true,
            talents = true,
            reptiles = true,
            #debug = true,
            #new3hexcharge = false,
            #setvschargechance = 50,
            #twohexchargechance = 75,
            #onehexchargechance = 50,
            #initialchargechance = 75,
            #newarmors = false,
            #nopolearmdouble = false,
            #minimum1dmg = true,
            #defending = false,
            #disengaging = false,
            #dxdifdisengage = false,
            #newpoleweapons = true,
            #minadjdx = 7,
            #maxadjdx = 20,
            #uc = false,
            #florentine = false,
            #isbrawlingstacking = true,
            #expertise = false,
            #monster = true,
            #maxnumberofturns = 30,
        )
    end
    Gmatcher = zeros(Int, Gsettings.numberofmatches)
end

function runsim()
    global Gtotalturns, Gsettings, Gprofile, Gpairs

    Gpairs = Set([(warrior, warrior) for warrior in Gwarriors])
    warriors = 0
    lastrest = 0
    for warrior1 in Gwarriors
        global Gp1 = WarriorState(warrior1)
        println(stderr, Gp1.warrior.id, ", TOTAL TURNS: ", Gtotalturns)
        for warrior2 in Gwarriors
            Gsettings.newrules && (warrior2, warrior1) in Gpairs && break
            push!(Gpairs, (warrior1, warrior2))
            global Gstatavgnumberofturns = 0
            global Gwin1 = 0
            global Gwin2 = 0
            global Gp2 = WarriorState(warrior2)
            fightfightfight()
            endmatchup(Gp1, Gwin1)
            endmatchup(Gp2, Gwin2)
            finishfighting(Gp2)
            warriornemesis(warrior1, warrior2, Gwin2)
            warriornemesis(warrior2, warrior1, Gwin1)
            Gtotalturns += Gstatavgnumberofturns
            if Gtotalturns - lastrest > 5000
                # This overheats my laptop unless it rests for 1 millisecond every so often!
                sleep(0.001)
                lastrest = Gtotalturns
            end
        end
        finishfighting(Gp1)
        warriors += 1
        if Gprofile && warriors > 10
            return
        end
    end
    setnemesistally()
end

function endmatchup(state, win)
    state.warrior.numberofwins += win
    state.warrior.numberofmatches += Gsettings.numberofmatches
    state.warrior.numberofturns += Gstatavgnumberofturns
end

function finishfighting(state)
    state.warrior.numberofhits += state.numberofhits
    state.warrior.damagedone += state.damagedone
    state.warrior.damagetaken += state.damagetaken
    state.warrior.armorabsorbed += state.armorabsorbed
end

function warriornemesis(warrior1, warrior2, losses)
    if warrior1.nemesislosses < losses
        warrior1.nemesis = warrior2
        warrior1.nemesislosses = losses
    end
end

function fightfightfight()
    global Gp1, Gp2

    for i in 1:Gsettings.numberofmatches
        resetplayer(Gp1)
        resetplayer(Gp2)
        for ii in 1:Gsettings.maxnumberofturns
            (Gp1.curst < (Gsettings.newrules ? 1 : 2) || Gp2.curst < (Gsettings.newrules ? 1 : 2)) && break
            chargeworking(Gp1, Gp2)
            if strikefirst(Gp1, Gp2) == 1
                firstplayer(Gp1, Gp2, true)
            else
                firstplayer(Gp2, Gp1, false)
            end
            turnmopup()
        end
        matchmopup(i)
    end
    matchsetmopup()
end

# return whether the first warrior should strike first
function strikefirst(p1, p2)
    charge1 = p1.warrior.weapon.polearm > 0 && p1.chargechance == 100 && p1.fallen == 0
    charge2 = p2.warrior.weapon.polearm > 0 && p2.chargechance == 100 && p2.fallen == 0
    debugprint("First strike - charge chances: ", p1.chargechance, ":", p2.chargechance)
    if charge1 != charge2 # only one is charging, whoever is goes first
        charge1 ? 1 : 2
    else
        pri1 = priority(p1, p2, charge1)
        pri2 = priority(p2, p1, charge2)
        debugprint("First strike - tohit chances: ", pri1, ":", pri2)
        pri1 > pri2 ? 1 : pri2 > pri1 ? 2 : random(2)
    end
end

priority(p1, p2, charge) = p1.warrior.adjdx + p1.tmpdxmod + charge * p1.setvschargebonus + p2.warrior.enemyadjdx

function strike(attacker, defender, defenderdefending, extraattack)
    attacker.warrior.numberofstrikes += 1
    tohit = 0
    charge = 0
    pronedefender = 0
    setvscharge = 0
    expertdefender = 0
    shrewdpenalty = 0
    secondattackpenalty = 0
    if attacker.fallen == 0
        if extraattack
            secondattackpenalty = attacker.warrior.weapon.dxpenaltysecondaryattack
        end
        tohit = d6(3)
        if attacker.warrior.weapon.polearm > 0 && attacker.chargechance == 100
            debugprint("chrage attack")
            if Gsettings.new3hexcharge
                if random(100) <= Gsettings.setvschargechance
                    debugprint("lucky set vs charge arrack")
                    setvscharge = 2
                end
            else
                debugprint("set vs charge attack")
                setvscharge = 2
            end
            global Gstatnumberofcharges += 1
        end
        if defender.fallen > 0
            pronedefender = 4
            global Gstatnumberofattacksonprone += 1
            debugprint("defender prone")
        end
        # basedx leaves out setvscharge
        basedx = attacker.warrior.adjdx + attacker.tmpdxmod + pronedefender - defender.warrior.enemyadjdx - secondattackpenalty
        expertdefender = defender.warrior.enemyadjdx
        if Gsettings.expertise && attacker.warrior.shrewd == 1
            shrewdpenalty = if attacker.weaponmastry == 1
                5
            elseif attacker.weaponmastry in [2, 3]
                4
            elseif attacker.weaponmastry == 4
                basedx >= 14 ? 3 : 4
            else
                0
            end
        end
        finaldx = basedx + setvscharge - expertdefender - shrewdpenalty
        tohit = if !(Gsettings.defending && defenderdefending) # inverted this check and moved to top
            d6(3)
        elseif defender.weaponmastry in [2, 4] || defender.warrior.uclevel == 5
            debugprint("defender master defending")
            d6(6)
        elseif defender.weaponmastry in [1, 3] || defender.warrior.uclevel == 4
            debugprint("defender expert defending")
            d6(5)
        else
            debugprint("defender defending")
            d6(4)
        end
        debugprint("Adjdx ", basedx + setvscharge, " to hit: ", tohit)
        if Gsettings.defending && defenderdefending
            if defender.weaponmastry in [2, 4] || defender.warrior.uclevel == 5 # Master Defending = 6d6
                if tohit <= max(14, min(27, finaldx))
                    hit(attacker, defender, false, false)
                elseif tohit > 28
                    attacker.fallen = 2 # Simulate dropped and broken weapon w/ knockdown.
                end
            elseif defender.weaponmastry in [1, 3] || defender.warrior.uclevel == 4 # Master Defending = 5d6
                if tohit <= max(11, min(23, finaldx))
                    hit(attacker, defender, false, false)
                elseif tohit > 24
                    attacker.fallen = 2 # Simulate dropped and broken weapon w/ knockdown.
                end
            # normal defending = 4d6
            elseif tohit <= max(8, min(19, finaldx))
                hit(attacker, defender, tohit == 4, tohit == 5)
            elseif tohit > 20
                attacker.fallen = 2 # Simulate dropped and broken weapon w/ knockdown.
            end
        # not defending
        elseif tohit <= max(5, min(15, finaldx))
            hit(attacker, defender, tohit == 3, tohit == 4)
        elseif tohit > 16
            attacker.fallen = 2 # Simulate dropped and broken weapon w/ knockdown.
        end
    end
    attacker.tmpdxmod = attacker.curst <= 3 ? -3 : 0
    attacker.chargechance = 0
end

function hit(attacker, defender, triple, double)
    dice = attacker.warrior.weapon.dice
    mod = attacker.warrior.weapon.mod
    dmg = d6(dice) + mod
    charge = attacker.warrior.weapon.polearm > 0 && attacker.chargechance == 100
    debugprint("Base dmg: d", dice, mod > 0 ? "+" : mod == 0 ? "" : "-", mod != 0 ? mod : "")
    pronedefender = defender.fallen > 0 ? 4 : 0
    if Gsettings.expertise
        if attacker.warrior.uclevel == 0 # UC damage is included in their base weapon stats
            if attacker.weaponmastry in [1, 3]
                dmg += 1 + (attacker.warrior.shrewd == 1 ? d6(1) : 0) # Expert/Fencer Shrewd / Expert/Fencer
            elseif attacker.weaponmastry in [2, 4]
                dmg += 2 + (attacker.warrior.shrewd == 1 ? d6(1) + 2 : 0) # Master/Fencer Shrewd / Master/Fencer
            end
        end
    end
    dmg *= double ? 2 : triple ? 3 : 1
    if charge
        dmg += Gsettings.nopolearmdouble ? d6(1) : dmg
    end
    defender.armorabsorbed += max(0, min(defender.warrior.armor, dmg))
    dmg = max((Gsettings.minimum1dmg ? 1 : 0), dmg - defender.warrior.armor)
    debugprint("Dmg after armor: ", dmg)
    defender.curst -= dmg
    if (defender.warrior.st >= 30 && dmg > 15) || (defender.warrior.st < 30 && dmg > 7)
        defender.fallen = 2
    elseif dmg > 4
        defender.tmpdxmod = -2
    end
    if dmg > 0
        attacker.lastattackdamaged = 1
        attacker.numberofhits += 1
        attacker.damagedone += dmg
        defender.damagetaken += dmg
    end
    debugprint("ST/adjST: ", defender.warrior.st, "/", defender.curst)
end

function chargeworking(p1, p2)
    if p1.chargechance > 0 && p2.chargechance > 0 # If both players have a charge ready they both charge.
        p1.chargechance = p1.chargechance = 100
    elseif p1.chargechance > 0
        p1.chargechance = (random(100) <= p1.chargechance ? 100 : 0)
        if p1.chargechance == 0
            debugprint("P1: lost initiative and no charge")
        end
    elseif p2.chargechance > 0
        p2.chargechance = (random(100) <= p2.chargechance ? 100 : 0)
        if p2.chargechance == 0
            debugprint("P2: lost initiative and no charge")
        end
    end
end

function dodisengage(attacker, defender)
    Gsettings.disengaging && attacker.fallen == 0 && # Must be standing
        attacker.warrior.weapon.polearm == 1 &&   # Rule of thumb: disengage if only you can charge
        defender.warrior.weapon.polearm == 0 &&
        attacker.chargechance == 0 &&      # Exception: you already have charge active
        (!Gsettings.dxdifdisengage ||                # Parting blow disengage
         defender.warrior.adjdx * 2 - attacker.warrior.adjdx < Gsettings.minadjdx) # Only disengage if low adj blow
end

function isdefenderdefending(attacker, defender)
    attackerhurtpremanently = attacker.curst <= 3 ? -3 : 0
    defenderhurtpremanently = defender.curst <= 3 ? -3 : 0
    # Defending is only a good option when the charging enemy can't disengage and do it again with higher adjDX.
    Gsettings.defending &&
        attacker.chargechance == 100 &&
        attacker.fallen == 0 &&
        defender.fallen == 0 &&
        defender.warrior.adjdx + defenderhurtpremanently - attacker.warrior.enemyadjdx > attacker.warrior.adjdx + attackerhurtpremanently - defender.warrior.enemyadjdx
end

function adjustforforcedretreat(p1, p2)
    if min(p1.curst, p2.curst) > (Gsettings.newrules ? 0 : 1)
        checkretreat(p1, p2, "P1")
        checkretreat(p2, p1, "P2")
    end
    p1.lastattackdamaged = p2.lastattackdamaged = 0
end

function checkretreat(p1, p2, name)
    if p1.lastattackdamaged == 1 && p2.lastattackdamaged == 0 &&
        p1.warrior.weapon.polearm == 1 && # Rule of thumb: Force retreat if only you can charge, or both can and you have a lower adjDX.
        (p2.warrior.weapon.polearm == 0 || p1.warrior.adjdx + p1.tmpdxmod < p2.warrior.adjdx + p2.tmpdxmod)
        global Gstatforcedretreats += 1
        debugprint(name * " forced a retreat")
        if Gsettings.new3hexcharge
            p1.chargechance = Gsettings.twohexchargechance # New charge possible.
            if p2.warrior.weapon.polearm == 1
                p2.chargechance = Gsettings.twohexchargechance # Enemy also gets a charge.
            end
        else
            p1.chargechance = 100 # New charge possible.
            if p2.warrior.weapon.polearm == 1
                p2.chargechance = 100 # Enemy also gets a charge.
            end
        end
    end
end

function adjarmortable()
    if !Gsettings.newarmors
        for a in 11:min(14, length(Garmortable))
            armor = Garmortable[a]
            Garmortable[a] = Armor(armor, armor.armor + 1 + armor.shield)
        end
    end
end

function adjweapontable()
    if Gsettings.newpoleweapons
        # javelin is same in both cases
        replaceweapon("Spear 1H", dice=1, mod=1)
        replaceweapon("Spear 2H", dice=2, mod=-2)
        # pike ax is same in both cases
        # halberd is same in both cases
   #else # TODO these are the values in the table
        # javelin is same in both cases
        #replaceweapon("Spear 1H", dice=1, mod=0)
        #replaceweapon("Spear 2H", dice=1, mod=1)
        # pike ax is same in both cases
        # halberd is same in both cases
    end 
    if Gsettings.newrules
        replaceweapon("Bastard Sword 2H", minimumst=13, dice=2, mod=2, twoh=1)
    else
        push!(Gweapontable, Weapon(18, "Naginata", 10, 1, 2, twoh=1, polearm=1))
    end
end

function replaceweapon(name::String; mods...)
    weapon = Weapon(Gweaponsbyname[name]; mods...)
    Gweaponsbyname[weapon.name] = weapon
    Gweapontable[weapon.id] = weapon
end

makename(st, dx, iq, weapon, armor) = "ST$st,DX$dx,IQ$iq,$(weapon.name),$(armor.armornamecombo)"

"""
    popwarriortable

Create a warrior for each weapon/armor combination
"""
function popwarriortable()
    for weapon in Gweapontable
        st = weapon.minimumst
        if Gsettings.points - st >= 16
            dx = Gsettings.points - 8 - st
            for armor in Garmortable
                # two-handed weapon -> no shield, one-handed weapon -> shield
                if ((weapon.twohanded == 1 && armor.shield == 0) || (weapon.twohanded == 0 && armor.shield > 0)) &&
                    (!(Gsettings.new3hexcharge && weapon.polearm == 1) || armor.id <= 8)
                    name=makename(st, dx, 8, weapon, armor)
                    warrior = Warrior(length(Gwarriors) + 1, name, st, dx, 8, weapon, protection(armor), armor, 0, 0, 0, 0, 0)
                    if Gsettings.minadjdx <= warrior.adjdx <= Gsettings.maxadjdx && isdxbelow20(warrior)
                        pushwarrior(warrior)
                    end
                    if Gsettings.expertise
                        if weapon.id in [2, 4]
                            addfencingwarriors(warrior)
                        else
                            addexpertisewarriors(warrior)
                        end
                    end
                    Gsettings.talents && addtalentwarriors(warrior)
                end
            end
        end
    end
    Gsettings.uc && adducwarriors()
    Gsettings.monster && addmonster()
    Gsettings.florentine && addflorentine()
end

function addexpertisewarriors(warrior)
    st = warrior.st
    dx = warrior.dx
    iq = 8
    adjdx = warrior.adjdx
    enemyadjdx = 0
    armor = warrior.armor
    armordata = warrior.armordata
    name = warrior.name
    weapon = warrior.weapon
    addwarrior(; expert=0, master=0, shrewd=0, name=name) = pushwarrior(Warrior(warrior; dx=dx, iq=iq, enemyadjdx=enemyadjdx, name=name, expert=expert, master=master, shrewd=shrewd, armor=armor, id=length(Gwarriors) + 1))
    if dx >= 14
        dx -= 2
        adjdx -= 2
        iq = 10
        enemyadjdx = 1
        name = makename(st, dx, iq, weapon, armordata) * ",Expert"
        if isdxbelow20(dx, adjdx)
            armor, enemyadjdx = shieldexpert(iq, warrior, armordata, enemyadjdx) #check for shield expert as well
            if adjdx >= Gsettings.minadjdx
                name, armor = toughness(st, iq, name, armor)  # if you already paid for IQ...
                addwarrior(expert=1)
            end
            if adjdx >= Gsettings.minadjdx + 5
                addwarrior(expert=1, shrewd = 1, name = name * ",Shrewd")
            end
        end
    end
    if dx >= 17
        dx -= 3
        adjdx -= 3
        if isdxbelow20(dx, adjdx)
            iq = 13
            name = makename(st, dx, iq, warrior.weapon, armordata) * ",Master"
            enemyadjdx = 2
            armor, enemyadjdx = shieldexpert(iq, warrior, armordata, enemyadjdx) #check for shield expert as well
            if dx >= Gsettings.minadjdx
                name, armor = toughness(st, iq, name, armor)  # if you already paid for IQ...
                addwarrior(master=1)
            end
            if adjdx >= Gsettings.minadjdx + 5
                addwarrior(master=1, shrewd=1, name = name * ",Shrewd")
            end
        end
    end
end

function addfencingwarriors(warrior)
    st = warrior.st
    dx = warrior.dx
    adjdx = warrior.adjdx
    iq = 8
    enemyadjdx = expert = master = shrewd = 0
    armor = warrior.armor
    armordata = warrior.armordata
    name = warrior.name
    weapon = warrior.weapon
    addwarrior(; expert=0, master=0, shrewd=0, name=name) = pushwarrior(Warrior(warrior; dx=dx, iq=iq, enemyadjdx=enemyadjdx, name=name, expert=expert, master=master, shrewd=shrewd, armor=armor, id=length(Gwarriors) + 1))
    if dx >= 15
        dx -= 2
        adjdx -= 2
        if isdxbelow20(dx, adjdx)
            iq = 10
            enemyadjdx = 1
            name = makename(st, dx, iq, weapon, armordata) * ",E.Fencer"
            armor, enemyadjdx = shieldexpert(iq, warrior, armordata, enemyadjdx) #check for shield expert as well
            addwarrior(expert=1)
            if adjdx >= 14 # good cut off point for shrewd
                addwarrior(expert=1, shrewd=1, name=name * ",Shrewd")
            end
        end
    end
    if dx >= 17
        dx -= 3
        adjdx -= 3
        if isdxbelow20(dx, adjdx)
            iq = 13
            enemyadjdx = 3
            name = makename(st, dx, iq, weapon, armordata) * ",M.Fencer"
            armor, enemyadjdx = shieldexpert(iq, warrior, armordata, enemyadjdx) # check for shield expert as well
            addwarrior(master=1)
            if adjdx >= 14 # good cut off point for shrewd
                addwarrior(master=1, shrewd=1, name=name * ",Shrewd")
            end
        end
    end
end

function addtalentwarriors(warrior)
    st = warrior.st
    dx = warrior.dx
    adjdx = warrior.adjdx
    iq = 8
    armor = warrior.armor
    name = warrior.name
    addwarrior() = pushwarrior(Warrior(warrior; dx=dx, iq=iq, name=name, armor=armor, id=length(Gwarriors) + 1))
    twohanded = warrior.weapon.twohanded
    if st >= (Gsettings.newrules ? 12 : 14) &&
        (dx >= (Gsettings.newrules ? 9 : 10)) &&
        (dx < 14 || !Gsettings.expertise) && # Combo of expertise and veterans talents are handled by Expertise.
        ((armor >= 3 && !Gsettings.newarmors && twohanded == 1) || # not until bad medium armor
         (armor == 5 && Gsettings.newarmors && twohanded == 1) || # not until good heavy armor
         (armor >= 6 && !Gsettings.newarmors && twohanded == 0) || # Not until bad heavy+shield armor
         (armor == 8 && Gsettings.newarmors && twohanded == 0)) # Not until good heavy+shield armor.
        dx -= (Gsettings.newrules ? 1 : 2)
        adjdx -= (Gsettings.newrules ? 1 : 2)
        iq = (Gsettings.newrules ? 9 : 10)
        name, armor = toughness(st, iq, name, armor)
        adjdx >= Gsettings.minadjdx && isdxbelow20(dx, adjdx) && addwarrior()
    end
end

function adducwarriors()
    adducwarriorlevel(1, 8, 8, 10, (0, 1), (0, 3), 4, 0)
    adducwarriorlevel(2, 8, 11, 11, (0, 2), (0, 5), 2, 1)
    adducwarriorlevel(3, 8, 12, 12, (0, 3), (1, 3), 0, 2)
    adducwarriorlevel(4, 11, 13, 13, (1, 0), (2, 1), 0, 2)
    adducwarriorlevel(5, 12, 14, 14, (1, 1), (2, 3), 0, 2)
    Gsettings.reptiles && addbrawlers()
end

# level, minst, mindx, iq, punchstats, kickstats, kickadj
function adducwarriorlevel(level, minst, mindx, iq, punchstats, kickstats, kickadj, enemyadjdx)
    local st, dx, name, armor, armordata
    warrior = Warrior(0, "", 0, 0, 0, Gweapontable[1], 0, Garmortable[1], 0, 0, 0, 0, 0)
    adjdx = 0
    addwarrior(weapon; name=name, extra="") = pushwarrior(Warrior(warrior; st=st, dx=dx, iq=iq, enemyadjdx=Gucevadepenalty[level], name=name * extra, armor=armor, armordata=armordata, id=length(Gwarriors) + 1, uclevel=level, weapon=weapon))
    basename() = "ST$st,DX$dx,IQ$iq,Unarmed $level$(armordata == noarmor() ? "" : "," * armordata.armornamecombo)"
    function setarmor(data::Armor)
        armordata = data
        adjdx = dx - armordata.dxpenalty
        name, armor = toughness(st, iq, basename(), protection(armordata) + Gucevadeprotection[level])
        #println(stderr, "$name: UC ARMOR: $(Gucevadeprotection[level]), final armor: $armor")
    end
    reptileweapon((dice, mod)::Tuple{Int, Int}) = getucweapon(level, st, dice, mod + 2)
    for i in mindx:Gsettings.points - iq - minst
        dx = adjdx = i
        st = Gsettings.points - i - iq
        punch = getucweapon(level, st, punchstats...)
        doublepunch = getucweapon(level, st, punchstats[1], punchstats[2] - 1, extraatks=1, name="Double Unarmed")
        reptiledouble = getucweapon(level, st, punchstats[1], punchstats[2] + 1, extraatks=1, name="Double Unarmed")
        kick = getucweapon(level, st, kickstats..., name="Kick")
        # no armor
        setarmor(noarmor())
        if isstok(st)
            if isdxbelow20(dx, adjdx)
                addwarrior(punch)
                Gsettings.newrules && level == 5 && addwarrior(doublepunch, extra=",Double")
                Gsettings.reptiles && st >= 12 && addwarrior(reptileweapon(punchstats), extra=",Reptile Man")
                Gsettings.reptiles && st >= 12 && level == 5 && addwarrior(reptiledouble, extra=",Reptile Man,Double")
                #kick
                if adjdx - kickadj >= Gsettings.minadjdx
                    addwarrior(kick, extra=",Kick")
                    Gsettings.reptiles && st >= 12 && addwarrior(reptileweapon(kickstats), extra=",Reptile Man,Kick")
                end
            end
            if dx >= 9
                # cloth
                setarmor(clotharmor())
                if isdxbelow20(dx, adjdx)
                    addwarrior(punch)
                    Gsettings.newrules && level == 5 && addwarrior(doublepunch, extra=",Double")
                    Gsettings.reptiles && st >= 12 && addwarrior(reptileweapon(punchstats), extra=",Reptile Man")
                    Gsettings.reptiles && st >= 12 && level == 5 && addwarrior(reptiledouble, extra=",Reptile Man,Double")
                    # cloth with kick
                    if adjdx - kickadj >= Gsettings.minadjdx
                        addwarrior(kick, extra=",Kick")
                        Gsettings.reptiles && st >= 12 && addwarrior(reptileweapon(kickstats), extra=",Reptile Man,Kick")
                    end
                end
            end
        end
    end
end

function getucweapon(level, st, bonusdice, bonusmod; extraatks=0, name="")
    minst, dice, mod = Gbarehanddamage[st]
    dice += bonusdice # dice and mod are different for punches and kicks
    mod += bonusmod
    get!(Gucweapons, (level, minst, dice, mod)) do
        Weapon(length(Gweapontable) + 1, "$(name == "" ? "Unarmed" : name) $level $(dice)d$(mod == 0 ? "" : mod < 0 ? "- $(-mod)" : "+ $mod")", minst, dice, mod; extraatks=extraatks)
    end
end

"""
    addbrawlers()

Brawlers fight dirty and do not defend bare handed
"""
function addbrawlers()
    local st, dx, iq, name, armor, armordata
    warrior = Warrior(length(Gwarriors) + 1, "", 12, 12, 8, Gweaponsbyname["Dagger"], 0, noarmor(), 0, 0, 0, 0, 0)
    enemyadjdx = adjdx = 0
    addwarrior(weapon, armor, name) = pushwarrior(Warrior(warrior; st=st, dx=dx, iq=iq, name=name, armor=armor, armordata=armordata, id=length(Gwarriors) + 1, weapon=weapon, enemyadjdx=enemyadjdx))
    basename() = "ST$st,DX$dx,IQ$iq,Reptile Brawler, $(armordata.armornamecombo)"
    setarmor(data) = (armordata = data; armor = protection(armordata); adjdx = dx - armordata.dxpenalty; name = basename())
    for rarmordata in Garmortable
        armordata = rarmordata
        for rst in reptilest
            iq = 8
            st = rst
            dx = Gsettings.points - st - iq
            dx < 8 && break
            enemyadjdx = 0
            weapon = getucweapon(0, st, 0, 4, name="Claws") # These Reptile Men fight dirty
            addwarrior(weapon, protection(armordata), basename())
            if dx >= 9
                dx -= 1
                iq += 1
                name, armor = toughness(st, iq, basename(), protection(armordata))
                addwarrior(weapon, armor, name)
                if dx >= 9 && armordata.shield > 0
                    dx -= 1
                    iq += 1
                    name, armor, enemyadjdx = shieldexpert(name, iq, warrior, armordata, enemyadjdx)
                    name, armor = toughness(st, iq, basename(), armor)
                    addwarrior(weapon, armor, name)
                end
            end
        end
    end
end

function shieldexpert(name, iq, warrior, armordata, enemyadjdx)
    a, e = shieldexpert(iq, warrior, armordata, enemyadjdx)
    (protection(armordata) < a ? name * ",Shield Expert" : name), a, e
end

function shieldexpert(iq, warrior, armordata, enemyadjdx)
    if iq >= 10 && armordata.shield > 0 && warrior.weapon.twohanded == 0
        protection(armordata) + 1, enemyadjdx + 1
    else
        protection(armordata), enemyadjdx
    end
end

function toughness(st, iq, name, armor)
    if !(Gsettings.talents || Gsettings.expertise) || st < (Gsettings.newrules ? 12 : 14) || iq < (Gsettings.newrules ? 9 : 10)
        name, armor
    elseif st >= (Gsettings.newrules ? 14 : 16)
        name * ",Veteran", armor + 2
    else
        name * ",Warrior", armor + 1
    end
end

random(num) = ceil(rand() * num)

function d6(dice)
    #reduce(+, random(6) for i in 1:dice)
    tot = 0
    for i in 1:dice
        tot += random(6)
    end
    tot
end

function firstplayer(pvfirstplayer, pvsecondplayer, isp1first)
    first = isp1first ? "P1" : "P2"
    debugprint(first * " goes first")
    if dodisengage(pvfirstplayer, pvsecondplayer)
        debugprint(first * " disengages")
        global Gnumberofdisengages += 1
        playerdisengages(pvfirstplayer, pvsecondplayer)
    elseif isdefenderdefending(pvfirstplayer, pvsecondplayer)
        if pvfirstplayer.fallen == 0
            strike(pvfirstplayer, pvsecondplayer, true, false)  # defender is defending. No attack after charge
            if pvfirstplayer.warrior.weapon.extraattacks == 1
                strike(pvfirstplayer, pvsecondplayer, true, true) # second attack
            end
        end
    else
        if pvfirstplayer.fallen == 0 # standing?
            strike(pvfirstplayer, pvsecondplayer, false, false)
            if pvfirstplayer.warrior.weapon.extraattacks == 1 # second attack
                strike(pvfirstplayer, pvsecondplayer, true, true)
            end
        end
        if pvsecondplayer.curst > (Gsettings.newrules ? 0 : 1) && pvsecondplayer.fallen == 0 # still alive and standing
            if dodisengage(pvsecondplayer, pvfirstplayer)
                debugprint((isp1first ? "P2" : "P1") * " disengages")
                global Gnumberofdisengages += 1
                playerdisengages(pvsecondplayer, pvfirstplayer)
            else
                strike(pvsecondplayer, pvfirstplayer, false, false)
                if pvsecondplayer.warrior.weapon.extraattacks == 1
                    strike(pvsecondplayer, pvfirstplayer, false, true)
                end
            end
        end
    end
end

function matchsetmopup()
    for i in 1:Gsettings.numberofmatches
        Gmatcher[i] == 1 && (global Gwin1 += 1)
        Gmatcher[i] == 2 && (global Gwin2 += 1)
        Gmatcher[i] == 3 && (global Gdraw += 1)
    end
end

function matchmopup(i)
    global Gmatcher
    Gmatcher[i] = if Gp2.curst < (Gsettings.newrules ? 1 : 2)
        debugprint("P1 won match")
        1
    elseif Gp1.curst < (Gsettings.newrules ? 1 : 2)
        debugprint("P2 won match")
        2
    else
        3
    end
end

function turnmopup()
    global Gp1, Gp2
    Gp1.fallen == 1 && (Gp1.fallen = 0)
    Gp1.fallen == 2 && (Gp1.fallen = 1)
    Gp2.fallen == 1 && (Gp2.fallen = 0)
    Gp2.fallen == 2 && (Gp2.fallen = 1)
    adjustforforcedretreat(Gp1, Gp2)
    global Gstatavgnumberofturns += 1
end

function resetplayer(player)
    player.curst = player.warrior.st
    player.tmpdxmod = 0
    player.chargechance = player.warrior.weapon.polearm * (Gsettings.new3hexcharge ? Gsettings.initialchargechance : 100)
    player.fallen = 0
    player.lastattackdamaged = 0
end

function playerdisengages(player1, player2)
    if Gsettings.new3hexcharge
        player1.chargechance = Gsettings.twohexchargechance
        player2.warrior.weapon.polearm == 1 && (player2.chargechance = Gsettings.twohexchargechance)
    else
        player1.chargechance = 100
        player2.warrior.weapon.polearm == 1 && (player2.chargechance = 100)
    end
end

isdxbelow20(warrior) = isdxbelow20(warrior.dx, warrior.weapon, warrior.armordata)
isdxbelow20(dx, weapon, armor) = isdxbelow20(dx, dx - armor.dxpenalty - weapon.dxpenaltyallattacks)
isdxbelow20(dx, adjdx) = dx <= (Gsettings.newrules ? 24 : 20) && adjdx <= Gsettings.maxadjdx

function addmonster()
    scales = Armor(15, "Scales", 3, 0)
    claws = Weapon(19, "Claws", 30, 2, -1, extraatks=1)
    base = Warrior(length(Gwarriors) + 1, "4-Hex Dragon", 30, 13, 16, claws, protection(scales), scales, 0, 0, 0, 0, 0)
    addmon = (;mods...)-> pushwarrior(Warrior(base; id = length(Gwarriors) + 1, mods...))
    addmon()
    addmon(name = "4-Hex Dragon, Claw Expert", expert = 1, enemyadjdx = 1)
    addmon(name = "4-Hex Dragon, Claw Master, Shrewd, Veteran", master = 1, enemyadjdx = 2, armor = 5, shrewd = 1)
    addmon(name = "4-Hex Dragon, Claw Master, Veteran", master = 1, enemyadjdx = 2, armor = 5)
end

function addflorentine()
    dagger = makeflorentine("Dagger")
    rapier = makeflorentine("Rapier")
    morningstar = makeflorentine("Morningstar")
    machete = makeflorentine("Cutlass", name="Machete")
    armordata = noarmor()
    base = Warrior(length(Gwarriors) + 1, "", 12, 12, 8, rapier, 0, armordata, 0, 0, 0, 0, 0)
    namefor(; extra="", st, dx, iq, weapon, armordata, mods...) = "ST$st,DX$dx,IQ$iq,$(weapon.name),$(armordata.armornamecombo)$extra"
    prep(mods) = filter(p-> p.first in Gwarriorkeys, pairs(mods))
    function addwarrior(w = base; mods...)
        warrior = Warrior(w; name=namefor(;st=w.st, dx=w.dx, iq=w.iq, weapon=w.weapon, armordata=w.armordata, mods...), id = length(Gwarriors) + 1, prep(mods)...)
        pushwarrior(warrior)
        warrior
    end
    if Gsettings.points >= 32
        dx = 13 + Gsettings.points - 32
        if isdxbelow20(dx, dx)
            for weapon in [rapier, dagger]
                w = addwarrior(;st=weapon.minimumst, dx=dx, iq=32 - weapon.minimumst - 13, expert=1, weapon=weapon, enemyadjdx=1, extra=",E.Fencer,Florentine")
                addwarrior(w; extra = ",E.Fencer,Florentine,Shrewd", shrewd=1)
            end
        end
    end
    if Gsettings.points >= 36
        dx = Gsettings.points - 13 - 11 # min 12
        if isdxbelow20(dx, dx)
            w = addwarrior(;st=13, dx=dx, iq=11, expert=1, weapon=morningstar, enemyadjdx=1, extra=",Expert,Florentine")
            if dx >= 14
                addwarrior(w; extra = ",Expert,Florentine,Shrewd", shrewd=1)
            end
        end
        dx = Gsettings.points - 9 - 11 # min 16
        if isdxbelow20(dx, dx)
            w = addwarrior(st=9, dx=dx, iq=13, master=1, weapon=rapier, enemyadjdx=3, extra=",M.Fencer,Florentine")
            addwarrior(w, extra = ",M.Fencer,Florentine,Shrewd", shrewd=1)
        end
        dx = Gsettings.points - 10 - 11 # min 15
        if isdxbelow20(dx, dx)
            w = addwarrior(st=10, dx=dx, iq=11, expert=1, weapon=machete, enemyadjdx=1, extra=",Expert,Florentine")
            addwarrior(w, extra = ",Expert,Florentine,Shrewd", shrewd=1)
        end
    end
    if Gsettings.points >= 40
        dx = Gsettings.points - 13 - 13 # min 14
        if isdxbelow20(dx, dx)
            w = addwarrior(st=13, dx=dx, iq=13, master=1, weapon=morningstar, enemyadjdx=2, extra=",Master,Florentine")
            addwarrior(w, extra = ",Master,Florentine,Shrewd", shrewd=1)
        end
    end
end

function setnemesistally()
    for w in Gwarriors
        if w.nemesis != nothing
            w.nemesis.nemesisofhowmany += 1
        end
    end
end

#debugprint(args...) = Gsettings.debug && println(stderr, args...)
debugprint(args...) = ()

isstok(st) = st in okst

#function filter(func, pp::Base.Iterators.Pairs)
#    p = pairs([p for p in pp if func(p)]
#end

function testTft(ARGS)
    global Gprofile

    setglobals(ARGS)
    adjarmortable()
    adjweapontable()
    popwarriortable()
    println(stderr, "$(length(Gweapontable)) Weapons, $(length(Gwarriors)) Warriors")
    if Gprofile
        println(stderr, "PROFILING...")
        @profile runsim()
        out = open("/tmp/profile", "w")
        #Profile.print(out, format=:flat)
        Profile.print(out)
        close(out)
    else
        runsim()
    end
    output()
end

function output()
    println(join(values(outputfields), ","))
    for w in Gwarriors
        println(join(map(k-> begin
                             p = getwarriorproperty(w, k)
                             isa(p, String) ? "\"$p\"" : p == nothing ? "" : isa(p, Real) ? round(p, digits=2) : p
                         end, keys(outputfields)), ","))
    end
end

#Profile.init(n=5000000)

profileSim() = @profile testTft([
    "-points"
    "32"
    "-orig"
])

if !isempty(ARGS)
    testTft(ARGS)
end
