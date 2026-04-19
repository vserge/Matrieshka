"""
    ContractorAgent

Implements contractor and subcontractor agents (Levels 2-3 per OTSU).

This module models general contractors, specialized subcontractors, and construction
organizations according to Russian legislation (SRO requirements, SNiP, GOST).
"""
module ContractorAgent

using ..AgentTypes
using ..StateAgent
using UUIDs
using Dates

"""
    ResourcePool

Contractor's resources including workforce, equipment, and materials.
"""
struct ResourcePool
    workforce::Dict{Symbol, Int}  # Workers by specialty
    equipment::Dict{Symbol, Int}  # Equipment by type
    materials::Dict{Symbol, Float64}  # Materials inventory
    capacity_utilization::Float64  # 0-1 scale
end

"""
    Schedule

Work schedule and timeline.
"""
mutable struct Schedule
    projects::Vector{Tuple{UUID, Date, Date}}  # (project_id, start, end)
    current_workload::Float64  # 0-1 scale
    available_capacity::Float64
    milestones::Vector{NamedTuple}
end

"""
    QualityMetrics

Quality and compliance metrics.
"""
struct QualityMetrics
    defect_rate::Float64  # Defects per 1000 units
    rework_percentage::Float64
    safety_incidents::Int
    compliance_score::Float64  # 0-1 scale
    certifications::Vector{Symbol}  # ISO, GOST, etc.
end

"""
    ContractorAgentData

Specialized data for contractor agents.
"""
mutable struct ContractorAgentData
    specialization::Vector{Specialization}
    sro_membership::Union{Nothing, SROMembership}
    resources::ResourcePool
    schedule::Schedule
    quality_metrics::QualityMetrics
    completed_projects::Vector{UUID}
    financial_state::Dict{Symbol, Money}
    licenses::Vector{License}
    key_personnel::Vector{Dict{Symbol, Any}}
end

# Constructor helper
function create_contractor_agent(name::String,
                                 specialization::Vector{Specialization};
                                 company_type::CompanyType=LLC,
                                 initial_workforce::Int=100)
    
    # Create base state agent (level 2 = general contractor, level 3 = subcontractor)
    system_level = length(specialization) == 1 ? Int8(3) : Int8(2)
    agent = StateAgent{ContractorAgent}(name, system_level)
    
    # Initialize resources
    resources = ResourcePool(
        workforce = Dict(:workers => initial_workforce, :engineers => div(initial_workforce, 10)),
        equipment = Dict(:cranes => 5, :excavators => 10, :trucks => 20),
        materials = Dict{Symbol, Float64}(),
        capacity_utilization = 0.5
    )
    
    # Initialize schedule
    schedule = Schedule(
        projects = [],
        current_workload = 0.5,
        available_capacity = 0.5,
        milestones = []
    )
    
    # Initialize quality metrics
    quality_metrics = QualityMetrics(
        defect_rate = 0.02,
        rework_percentage = 0.05,
        safety_incidents = 0,
        compliance_score = 0.9,
        certifications = [:ISO9001, :GOST]
    )
    
    # Initialize specialized data
    data = ContractorAgentData(
        specialization = specialization,
        sro_membership = nothing,
        resources = resources,
        schedule = schedule,
        quality_metrics = quality_metrics,
        completed_projects = UUID[],
        financial_state = Dict(:revenue => Money(0), :costs => Money(0), :profit => Money(0)),
        licenses = License[],
        key_personnel = []
    )
    
    # Store in agent state
    update_state!(agent, :contractor_data, data)
    update_state!(agent, :agent_type, :contractor)
    
    # Add emergence properties typical for contractors
    add_emergence_property!(agent, :production_capacity)
    add_emergence_property!(agent, :quality_reputation)
    add_emergence_property!(agent, :schedule_reliability)
    
    return agent, data
end

"""
    bid_for_project(agent::StateAgent, project_id::UUID,
                    estimated_cost::Money, duration::TimePeriod)

Submit a bid for a construction project.
"""
function bid_for_project(agent::StateAgent, project_id::UUID,
                        estimated_cost::Money, duration::TimePeriod)
    data = agent.state[:contractor_data]
    
    # Check capacity
    if data.schedule.available_capacity < 0.3
        return nothing  # Not enough capacity
    end
    
    # Calculate bid with markup
    markup = 1.0 + rand(0.1:0.05:0.3)  # 10-30% markup
    bid_price = estimated_cost * markup
    
    bid = (
        id = uuid4(),
        contractor_id = agent.id,
        project_id = project_id,
        price = bid_price,
        duration = duration,
        submission_date = Dates.now(),
        validity_period = TimePeriod(90, :day)
    )
    
    record_interaction!(agent, (
        action = :bid_submitted,
        project_id = project_id,
        price = bid_price
    ))
    
    return bid
end

"""
    accept_project!(agent::StateAgent, project_id::UUID,
                    start_date::Date, end_date::Date,
                    contract_value::Money)

Accept a project and update schedule.
"""
function accept_project!(agent::StateAgent, project_id::UUID,
                        start_date::Date, end_date::Date,
                        contract_value::Money)
    data = agent.state[:contractor_data]
    
    # Add to schedule
    push!(data.schedule.projects, (project_id, start_date, end_date))
    
    # Update workload
    data.schedule.current_workload = min(1.0, data.schedule.current_workload + 0.2)
    data.schedule.available_capacity = 1.0 - data.schedule.current_workload
    
    # Update financials
    data.financial_state[:revenue] = data.financial_state[:revenue] + contract_value
    
    update_state!(agent, :contractor_data, data)
    
    record_interaction!(agent, (
        action = :project_accepted,
        project_id = project_id,
        value = contract_value
    ))
    
    return agent
end

"""
    complete_project!(agent::StateAgent, project_id::UUID,
                      actual_duration::TimePeriod, quality_score::Float64)

Mark a project as completed.
"""
function complete_project!(agent::StateAgent, project_id::UUID,
                          actual_duration::TimePeriod, 
                          quality_score::Float64)
    data = agent.state[:contractor_data]
    
    # Remove from active projects
    filter!(p -> p[1] != project_id, data.schedule.projects)
    
    # Add to completed
    push!(data.completed_projects, project_id)
    
    # Update schedule
    data.schedule.current_workload = max(0.0, data.schedule.current_workload - 0.2)
    data.schedule.available_capacity = 1.0 - data.schedule.current_workload
    
    # Update quality metrics
    if quality_score < 0.8
        data.quality_metrics.defect_rate += 0.01
    else
        data.quality_metrics.defect_rate = max(0.0, data.quality_metrics.defect_rate - 0.005)
    end
    
    update_state!(agent, :contractor_data, data)
    
    record_interaction!(agent, (
        action = :project_completed,
        project_id = project_id,
        quality_score = quality_score
    ))
    
    return agent
end

"""
    assess_capability(agent::StateAgent, 
                     required_specialization::Specialization,
                     required_capacity::Float64)

Assess contractor's capability for specific work.
"""
function assess_capability(agent::StateAgent, 
                          required_specialization::Specialization,
                          required_capacity::Float64)
    data = agent.state[:contractor_data]
    
    # Check specialization
    has_specialization = required_specialization in data.specialization
    
    # Check capacity
    has_capacity = data.schedule.available_capacity >= required_capacity
    
    # Check SRO membership
    has_sro = data.sro_membership !== nothing && 
              data.sro_membership.status == :active
    
    # Calculate capability score
    score = (
        (has_specialization ? 0.4 : 0.0) +
        (has_capacity ? 0.3 : 0.0) +
        (has_sro ? 0.3 : 0.0)
    )
    
    return (
        capable = score > 0.5,
        score = score,
        details = Dict(
            :specialization_match => has_specialization,
            :capacity_available => has_capacity,
            :sro_compliant => has_sro,
            :quality_score => data.quality_metrics.compliance_score
        )
    )
end

"""
    update_resources!(agent::StateAgent, 
                      workforce_change::Int,
                      equipment_additions::Dict{Symbol, Int})

Update contractor's resource pool.
"""
function update_resources!(agent::StateAgent,
                          workforce_change::Int,
                          equipment_additions::Dict{Symbol, Int})
    data = agent.state[:contractor_data]
    
    # Update workforce
    data.resources.workforce[:workers] += workforce_change
    
    # Update equipment
    for (equip_type, count) in equipment_additions
        data.resources.equipment[equip_type] = 
            get(data.resources.equipment, equip_type, 0) + count
    end
    
    update_state!(agent, :contractor_data, data)
    return agent
end

"""
    contractor_behavior(agent::StateAgent, environment, time::DateTime)

Default behavior function for contractor agents.
"""
function contractor_behavior(agent::StateAgent, environment, time::DateTime)
    data = agent.state[:contractor_data]
    
    # Periodic activities
    # - Execute ongoing projects
    # - Bid for new projects
    # - Manage resources
    # - Quality control
    # - Safety inspections
    # - Report progress
    
    return nothing
end

export ContractorAgentData, ResourcePool, Schedule, QualityMetrics
export create_contractor_agent, bid_for_project, accept_project!
export complete_project!, assess_capability, update_resources!
export contractor_behavior

end # module ContractorAgent
