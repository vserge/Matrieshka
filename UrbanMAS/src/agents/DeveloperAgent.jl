"""
    DeveloperAgent

Implements developer/builder agents (Level 1 per OTSU).

This module models construction developers and investors, including private companies,
state-owned enterprises, and corporations engaged in capital construction projects
according to Russian legislation (214-FZ, Gradostroitelny Kodeks).
"""
module DeveloperAgent

using ..AgentTypes
using ..StateAgent
using UUIDs
using Dates

"""
    FinancialState

Represents the financial condition of a developer.
"""
struct FinancialState
    assets::Money
    liabilities::Money
    equity::Money
    cash_flow::Money
    credit_rating::Float64  # 0-1 scale
    debt_to_equity::Float64
    current_ratio::Float64
    last_updated::DateTime
end

"""
    RiskProfile

Developer's risk profile and tolerance.
"""
struct RiskProfile
    risk_tolerance::Float64  # 0-1 scale
    exposure_limits::Dict{Symbol, Money}
    hedging_strategies::Vector{Symbol}
    insurance_coverage::Money
    risk_register::Vector{RiskItem}
end

"""
    Project

Represents a construction project in developer's portfolio.
"""
mutable struct Project
    id::UUID
    name::String
    type::Symbol  # :residential, :commercial, :industrial, :infrastructure
    status::ProjectStatus
    location::String
    total_area::Float64  # sq meters
    estimated_cost::Money
    funding_sources::Vector{Tuple{Symbol, Money}}
    timeline::Dict{Symbol, Date}
    permits::Vector{Document}
    contractors::Vector{UUID}
    completion_percentage::Float64
    risks::Vector{RiskItem}
end

"""
    Document

Permit or approval document.
"""
struct Document
    id::UUID
    type::DocumentType
    status::DocumentStatus
    issue_date::Date
    expiry_date::Date
    issuing_authority::UUID
    content::Dict{Symbol, Any}
end

"""
    RiskItem

Individual risk item.
"""
struct RiskItem
    id::UUID
    category::RiskCategory
    description::String
    probability::Float64
    impact::Money
    mitigation::Union{Nothing, String}
end

"""
    DeveloperAgentData

Specialized data for developer agents.
"""
mutable struct DeveloperAgentData
    company_type::CompanyType
    license::Union{Nothing, License}
    portfolio::Vector{Project}
    financial_state::FinancialState
    risk_profile::RiskProfile
    compliance_status::ComplianceStatus
    sro_membership::Union{Nothing, SROMembership}
    bank_accounts::Vector{Dict{Symbol, Any}}
    escrow_accounts::Vector{Dict{Symbol, Any}}  # For 214-FZ compliance
end

# Constructor helper
function create_developer_agent(name::String,
                                company_type::CompanyType;
                                initial_assets::Money=Money(1e9),
                                jurisdiction::String="РФ")
    
    # Create base state agent (level 1 = developer/investor)
    agent = StateAgent{DeveloperAgent}(name, 1)
    
    # Initialize financial state
    financial_state = FinancialState(
        assets = initial_assets,
        liabilities = Money(0),
        equity = initial_assets,
        cash_flow = Money(0),
        credit_rating = 0.7,
        debt_to_equity = 0.0,
        current_ratio = 2.0,
        last_updated = Dates.now()
    )
    
    # Initialize risk profile
    risk_profile = RiskProfile(
        risk_tolerance = 0.5,
        exposure_limits = Dict(:single_project => Money(5e8), :total => initial_assets),
        hedging_strategies = Symbol[],
        insurance_coverage = Money(1e9),
        risk_register = RiskItem[]
    )
    
    # Initialize specialized data
    data = DeveloperAgentData(
        company_type = company_type,
        license = nothing,
        portfolio = Project[],
        financial_state = financial_state,
        risk_profile = risk_profile,
        compliance_status = Compliant,
        sro_membership = nothing,
        bank_accounts = [Dict(:type => :settlement, :balance => initial_assets)],
        escrow_accounts = []
    )
    
    # Store in agent state
    update_state!(agent, :developer_data, data)
    update_state!(agent, :agent_type, :developer)
    
    # Add emergence properties typical for developers
    add_emergence_property!(agent, :investment_capacity)
    add_emergence_property!(agent, :market_influence)
    add_emergence_property!(agent, :project_coordination)
    
    return agent, data
end

"""
    add_project!(agent::StateAgent, project::Project)

Add a project to the developer's portfolio.
"""
function add_project!(agent::StateAgent, project::Project)
    data = agent.state[:developer_data]
    push!(data.portfolio, project)
    
    # Update financial state
    data.financial_state.assets = data.financial_state.assets + project.estimated_cost
    
    update_state!(agent, :developer_data, data)
    return agent
end

"""
    obtain_permit(agent::StateAgent, project_id::UUID,
                  permit_type::DocumentType, authority_id::UUID)

Apply for and obtain a construction permit.
"""
function obtain_permit(agent::StateAgent, project_id::UUID,
                      permit_type::DocumentType, authority_id::UUID)
    data = agent.state[:developer_data]
    
    # Find project
    project = findfirst(p -> p.id == project_id, data.portfolio)
    if project === nothing
        error("Project not found: $project_id")
    end
    
    # Create permit document
    permit = Document(
        id = uuid4(),
        type = permit_type,
        status = UnderReview,
        issue_date = today(),
        expiry_date = today() + Year(3),
        issuing_authority = authority_id,
        content = Dict(:project_id => project_id)
    )
    
    # In real simulation, this would interact with GovernmentAgent
    # For now, simulate approval
    permit.status = Approved
    permit.issue_date = today()
    
    push!(data.portfolio[project].permits, permit)
    update_state!(agent, :developer_data, data)
    
    record_interaction!(agent, (
        action = :permit_obtained,
        permit_type = permit_type,
        project_id = project_id,
        authority = authority_id
    ))
    
    return permit
end

"""
    hire_contractor(agent::StateAgent, project_id::UUID,
                    contractor_id::UUID, contract_value::Money)

Hire a contractor for a project.
"""
function hire_contractor(agent::StateAgent, project_id::UUID,
                        contractor_id::UUID, contract_value::Money)
    data = agent.state[:developer_data]
    
    # Find project
    project_idx = findfirst(p -> p.id == project_id, data.portfolio)
    if project_idx === nothing
        error("Project not found: $project_id")
    end
    
    # Add contractor
    push!(data.portfolio[project_idx].contractors, contractor_id)
    update_state!(agent, :developer_data, data)
    
    # Update financials
    data.financial_state.liabilities = data.financial_state.liabilities + contract_value
    
    record_interaction!(agent, (
        action = :contractor_hired,
        project_id = project_id,
        contractor_id = contractor_id,
        value = contract_value
    ))
    
    return agent
end

"""
    update_project_progress(agent::StateAgent, project_id::UUID,
                           completion_pct::Float64, costs_incurred::Money)

Update project completion percentage and costs.
"""
function update_project_progress(agent::StateAgent, project_id::UUID,
                                completion_pct::Float64, 
                                costs_incurred::Money)
    data = agent.state[:developer_data]
    
    project_idx = findfirst(p -> p.id == project_id, data.portfolio)
    if project_idx === nothing
        error("Project not found: $project_id")
    end
    
    data.portfolio[project_idx].completion_percentage = completion_pct
    
    # Update cash flow
    data.financial_state.cash_flow = data.financial_state.cash_flow - costs_incurred
    
    update_state!(agent, :developer_data, data)
    return agent
end

"""
    assess_financial_health(agent::StateAgent)

Assess the developer's financial health.
"""
function assess_financial_health(agent::StateAgent)
    data = agent.state[:developer_data]
    fs = data.financial_state
    
    # Calculate metrics
    equity_ratio = fs.equity.amount / max(fs.assets.amount, 1)
    liquidity_adequate = fs.current_ratio > 1.5
    debt_manageable = fs.debt_to_equity < 2.0
    
    health_score = (
        equity_ratio * 0.3 +
        (liquidity_adequate ? 0.35 : 0.0) +
        (debt_manageable ? 0.35 : 0.0)
    )
    
    return (
        score = health_score,
        rating = health_score > 0.7 ? :good : (health_score > 0.4 ? :moderate : :poor),
        metrics = Dict(
            :equity_ratio => equity_ratio,
            :current_ratio => fs.current_ratio,
            :debt_to_equity => fs.debt_to_equity
        )
    )
end

"""
    developer_behavior(agent::StateAgent, environment, time::DateTime)

Default behavior function for developer agents.
"""
function developer_behavior(agent::StateAgent, environment, time::DateTime)
    data = agent.state[:developer_data]
    
    # Periodic activities
    # - Monitor project progress
    # - Manage cash flows
    # - Seek new projects
    # - Compliance reporting
    # - Stakeholder communications
    
    return nothing
end

export DeveloperAgentData, FinancialState, RiskProfile, Project, Document, RiskItem
export create_developer_agent, add_project!, obtain_permit, hire_contractor
export update_project_progress, assess_financial_health, developer_behavior

end # module DeveloperAgent
