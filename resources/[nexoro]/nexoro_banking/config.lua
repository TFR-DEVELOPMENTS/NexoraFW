Config = {}

Config.Banking = {
    MaxSingleTransactionPounds = 1000000.00,
    MaxBalancePounds = 1000000000.00,      -- must match nexoro_core Config.Framework.MaxBalancePounds
    StatementPageSize = 25,

    -- Salaries are paid into the bank account. Non-civilian jobs (police, NHS, etc.) are paid only while on duty.
    SalaryIntervalMinutes = 15,
}
