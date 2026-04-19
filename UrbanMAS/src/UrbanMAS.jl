module UrbanMAS

__precompile__()

# Core modules
include("agents/AgentTypes.jl")
include("agents/StateAgent.jl")
include("agents/GovernmentAgent.jl")
include("agents/DeveloperAgent.jl")
include("agents/ContractorAgent.jl")
include("agents/SupplierAgent.jl")
include("agents/OperatorAgent.jl")

include("environment/Environment.jl")
include("environment/Legislation.jl")
include("environment/Market.jl")
include("environment/Infrastructure.jl")

include("processes/CapitalInvestment.jl")
include("processes/Lifecycle.jl")
include("processes/Procurement.jl")
include("processes/Permitting.jl")

include("economics/CostModels.jl")
include("economics/RiskAnalysis.jl")
include("economics/Optimization.jl")
include("economics/Metrics.jl")

include("simulation/Scheduler.jl")
include("simulation/Engine.jl")
include("simulation/Scenarios.jl")

include("utils/DataIO.jl")
include("utils/Visualization.jl")
include("utils/Logging.jl")

# Re-export main types and functions
export 
    # Agents
    AbstractAgent, StateAgent, GovernmentAgent, DeveloperAgent,
    ContractorAgent, SupplierAgent, OperatorAgent,
    
    # Environment
    UrbanEnvironment, LegislationModel, MarketModel, InfrastructureGraph,
    
    # Processes
    InvestmentPortfolio, InvestmentProject, AssetLifecycle, LifecycleStage,
    ProcurementProcedure, GradingDocumentation,
    
    # Economics
    CostEstimate, RiskRegister, RiskItem,
    
    # Simulation
    SimulationEngine, Event, Scenario,
    
    # System metrics
    SystemIntegrityMetrics, EmergenceDetector,
    
    # Main functions
    create_agent, run_simulation, optimize_portfolio,
    evaluate_project_lifecycle, calculate_system_metrics,
    detect_emergence, generate_report

# Version information
const VERSION = VersionNumber(0, 1, 0)

"""
    UrbanMAS

Multi-agent system for urban planning and construction activity simulation.

This package implements a comprehensive framework for modeling construction industry
participants from government agencies to suppliers, based on:
- OTSU (Urmantsev's General Systems Theory)
- OTS (Yemov's General Systems Theory)

Key features:
- Multi-level agent hierarchy (6 levels from government to operators)
- Russian legislation compliance (Gradostroitelny Kodeks, 44-FZ, 223-FZ)
- Capital investment management
- Asset lifecycle analysis
- Economic modeling and risk analysis
- Emergence properties monitoring

# Example
```julia
using UrbanMAS

# Initialize environment
env = UrbanEnvironment(region = Region("Московская область"))

# Create agents
gov = create_agent(GovernmentAgent, level=:regional)
dev = create_agent(DeveloperAgent)

# Run simulation
scenario = Scenario(name="Test Scenario")
engine = SimulationEngine(environment=env)
results = run_simulation(engine, scenario)
```
"""
UrbanMAS
