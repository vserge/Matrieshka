"""
    GovernmentAgent

Implements government and regulatory agency agents (Level 0 per OTSU).

This module models federal, regional, and municipal government bodies involved
in construction regulation, permitting, and oversight according to Russian legislation.
"""
module GovernmentAgent

using ..AgentTypes
using ..StateAgent
using UUIDs
using Dates

"""
    Regulation

Represents a regulatory act or requirement.
"""
struct Regulation
    id::UUID
    name::String
    type::Symbol  # :federal_law, :decree, :order, :standard, :sanpin
    number::String
    issue_date::Date
    effective_date::Date
    expiry_date::Union{Nothing, Date}
    issuing_body::String
    scope::Vector{Symbol}
    requirements::Dict{Symbol, Any}
end

"""
    ControlMechanism

Represents a control or enforcement mechanism.
"""
struct ControlMechanism
    type::Symbol  # :inspection, :audit, :permit, :license, :fine
    authority::String
    frequency::TimePeriod
    penalties::Vector{Tuple{Symbol, Money}}
end

"""
    GovernmentAgentData

Specialized data for government agents.
"""
mutable struct GovernmentAgentData
    level::GovernmentLevel
    authority::Vector{Symbol}
    regulations::Vector{Regulation}
    budget::Budget
    control_mechanisms::Vector{ControlMechanism}
    jurisdiction::String  # Geographic area
    departments::Vector{String}
    digital_services::Vector{String}  # E.g., Gosuslugi integration
end

# Constructor helper
function create_government_agent(name::String, 
                                 level::GovernmentLevel,
                                 jurisdiction::String;
                                 authority::Vector{Symbol}=Symbol[],
                                 budget_total::Money=Money(0),
                                 regulations::Vector{Regulation}=Regulation[])
    
    # Create base state agent (level 0 = government)
    agent = StateAgent{GovernmentAgent}(name, 0)
    
    # Initialize specialized data
    data = GovernmentAgentData(
        level = level,
        authority = authority,
        regulations = regulations,
        budget = Budget(budget_total),
        control_mechanisms = ControlMechanism[],
        jurisdiction = jurisdiction,
        departments = String[],
        digital_services = String[]
    )
    
    # Store in agent state
    update_state!(agent, :government_data, data)
    update_state!(agent, :agent_type, :government)
    
    # Add emergence properties typical for government agents
    add_emergence_property!(agent, :regulatory_influence)
    add_emergence_property!(agent, :system_coordination)
    
    return agent, data
end

"""
    add_regulation!(agent::StateAgent, regulation::Regulation)

Add a regulation to the government agent's authority.
"""
function add_regulation!(agent::StateAgent, regulation::Regulation)
    data = agent.state[:government_data]
    push!(data.regulations, regulation)
    update_state!(agent, :government_data, data)
    return agent
end

"""
    add_control_mechanism!(agent::StateAgent, mechanism::ControlMechanism)

Add a control mechanism to the government agent.
"""
function add_control_mechanism!(agent::StateAgent, mechanism::ControlMechanism)
    data = agent.state[:government_data]
    push!(data.control_mechanisms, mechanism)
    update_state!(agent, :government_data, data)
    return agent
end

"""
    issue_permit(agent::StateAgent, applicant_id::UUID, 
                 permit_type::DocumentType, conditions::Dict)

Issue a permit or approval document.
"""
function issue_permit(agent::StateAgent, applicant_id::UUID, 
                     permit_type::DocumentType, 
                     conditions::Dict{Symbol, Any})
    data = agent.state[:government_data]
    
    # Check authority
    if !haskey(data.authority, permit_type)
        error("Agent does not have authority to issue $(permit_type)")
    end
    
    permit = (
        id = uuid4(),
        type = permit_type,
        issuer = agent.id,
        recipient = applicant_id,
        issue_date = Dates.now(),
        conditions = conditions,
        status = :active
    )
    
    record_interaction!(agent, (
        action = :permit_issued,
        permit_type = permit_type,
        recipient = applicant_id
    ))
    
    return permit
end

"""
    conduct_inspection(agent::StateAgent, target_id::UUID,
                      inspection_type::Symbol)

Conduct an inspection or audit.
"""
function conduct_inspection(agent::StateAgent, target_id::UUID,
                           inspection_type::Symbol)
    data = agent.state[:government_data]
    
    # Simulate inspection results
    findings = []
    violations = []
    compliance_score = rand() * 0.3 + 0.7  # 0.7 to 1.0
    
    if compliance_score < 0.85
        push!(violations, (
            type = :minor,
            description = "Minor compliance issue detected",
            penalty = Money(rand(10000:100000))
        ))
    end
    
    inspection_result = (
        id = uuid4(),
        inspector = agent.id,
        target = target_id,
        inspection_type = inspection_type,
        date = Dates.now(),
        compliance_score = compliance_score,
        findings = findings,
        violations = violations,
        recommendations = String[]
    )
    
    record_interaction!(agent, (
        action = :inspection_conducted,
        target = target_id,
        result = compliance_score
    ))
    
    return inspection_result
end

"""
    update_budget!(agent::StateAgent, allocation::Money)

Update the government agent's budget allocation.
"""
function update_budget!(agent::StateAgent, allocation::Money)
    data = agent.state[:government_data]
    data.budget.allocated = allocation
    update_state!(agent, :government_data, data)
    return agent
end

"""
    get_applicable_regulations(agent::StateAgent, 
                               context::Symbol)

Get regulations applicable to a specific context.
"""
function get_applicable_regulations(agent::StateAgent, context::Symbol)
    data = agent.state[:government_data]
    return filter(r -> context in r.scope, data.regulations)
end

"""
    government_behavior(agent::StateAgent, environment, time::DateTime)

Default behavior function for government agents.
"""
function government_behavior(agent::StateAgent, environment, time::DateTime)
    data = agent.state[:government_data]
    
    # Periodic activities
    # - Process permit applications
    # - Conduct scheduled inspections
    # - Update regulations
    # - Report to higher levels
    
    return nothing
end

export GovernmentAgentData, Regulation, ControlMechanism
export create_government_agent, add_regulation!, add_control_mechanism!
export issue_permit, conduct_inspection, update_budget!
export get_applicable_regulations, government_behavior

end # module GovernmentAgent
