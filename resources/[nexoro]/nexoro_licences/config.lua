Config = {}

Config.Licences = {
    -- The council office where licences are bought. Coordinates are placeholders.
    Office = { label = 'Council Licensing Office', x = 252.0, y = -1048.0, z = 29.3, radius = 3.0 },
    Fishing = { label = 'Fishing licence', feePounds = 25.00 },
    Hunting = { label = 'Hunting licence', feePounds = 40.00 },
    Weapon = { label = 'Weapon licence', feePounds = 500.00 },
    Driving = {
        label = 'Driving licence',
        feePounds = 60.00,
        questionsPerTest = 5,
        passMark = 4,
        item = 'driving_licence',
        -- The answers stay on the server. Players only see the question and options.
        bank = {
            { q = 'What does a solid white line along the edge of the road mean?', options = { 'Parking is allowed', 'Stop only at junctions', 'Do not cross or drive over it', 'Bus lane only' }, answer = 3 },
            { q = 'When must you use your headlights?', options = { 'Only at night', 'When visibility is poor', 'Never in the city', 'Only on motorways' }, answer = 2 },
            { q = 'What is the national speed limit for a car on a single carriageway?', options = { '50 mph', '60 mph', '70 mph', '40 mph' }, answer = 2 },
            { q = 'How far should you leave between you and the car in front in good conditions?', options = { 'One car length', 'Two seconds', 'Half a car length', 'As close as needed' }, answer = 2 },
            { q = 'What should you do at a zebra crossing when someone is waiting to cross?', options = { 'Sound your horn', 'Slow down and give way', 'Drive around them', 'Flash your lights' }, answer = 2 },
            { q = 'When is it legal to use a hand-held phone while driving?', options = { 'Never', 'At red lights', 'When parked safely with the engine off', 'On quiet roads' }, answer = 3 },
            { q = 'What does a red circle with a white bar mean?', options = { 'No entry', 'Give way', 'Parking', 'Hospital' }, answer = 1 },
            { q = 'Which lane should you use for a left turn on a roundabout?', options = { 'The right-hand lane', 'The left-hand lane', 'Any lane', 'The middle lane' }, answer = 2 },
            { q = 'How often should you check your tyre pressures?', options = { 'Once a year', 'Every few weeks', 'Only after a puncture', 'Never' }, answer = 2 },
            { q = 'What must you do if you are involved in an accident causing injury?', options = { 'Drive home', 'Stop and report it to the police', 'Only exchange details', 'Post it online' }, answer = 2 },
        },
    },
}
