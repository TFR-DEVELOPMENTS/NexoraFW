exports('ValidateCharacter', function(data) return NexoroIdentity.ValidateCharacter(data) end)
exports('GenerateCitizenId', function() return NexoroIdentity.GenerateCitizenId() end)
exports('IsValidCitizenId', function(id) return NexoroIdentity.IsValidCitizenId(id) end)
exports('GetOptions', function()
    return {
        genders = Config.Identity.Genders, nationalities = Config.Identity.Nationalities,
        minAge = Config.Identity.MinAge, maxAge = Config.Identity.MaxAge,
        minHeight = Config.Identity.MinHeight, maxHeight = Config.Identity.MaxHeight,
        maxBiography = Config.Identity.MaxBiography, maxNameLength = Config.Identity.MaxNameLength,
    }
end)
