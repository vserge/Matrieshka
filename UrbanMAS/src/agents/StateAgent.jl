"""
    StateAgent

Implements the base stateful agent structure based on OTSU (Urmantsev's General Systems Theory).

This module provides the foundational agent type with system-level properties,
emergence characteristics, and integrity factors as defined in OTSU methodology.
"""
module StateAgent

using ..AgentTypes
using UUIDs
using Dates

"""
    StateAgent{T<:AbstractAgent}

Base mutable struct for all agents in the UrbanMAS system.

# Fields
- `id`: Unique identifier
- `type`: Concrete agent type
- `name`: Human-readable name
- `state`: Current state dictionary
- `behavior`: Behavior function
- `connections`: List of connected agent IDs
- `history`: Interaction history
- `system_level`: Hierarchy level (0-5 per OTSU)
- `emergence_properties`: List of emergent properties
- `integrity_factor`: System integrity coefficient (0-1)
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp
"""
mutable struct StateAgent{T<:AbstractAgent} <: AbstractAgent
    id::UUID
    type::Type{T}
    name::String
    state::Dict{Symbol, Any}
    behavior::Function
    connections::Vector{UUID}
    history::Vector{NamedTuple}
    
    # OTSU parameters
    system_level::Int8  # 0 (government) to 5 (operators)
    emergence_properties::Vector{Symbol}
    integrity_factor::Float64  # 0.0 to 1.0
    
    # Metadata
    created_at::DateTime
    updated_at::DateTime
    
    function StateAgent{T}(id::UUID, name::String, system_level::Int8) where T<:AbstractAgent
        now = Dates.now()
        agent = new(
            id,
            T,
            name,
            Dict{Symbol, Any}(),
            default_behavior,
            UUID[],
            NamedTuple[],
            system_level,
            Symbol[],
            1.0,  # Default integrity factor
            now,
            now
        )
        return agent
    end
end

# Default constructor
function StateAgent(T::Type{<:AbstractAgent}, name::String, system_level::Int8)
    id = uuid4()
    return StateAgent{T}(id, name, system_level)
end

# Default behavior function
function default_behavior(agent::StateAgent, environment, time::DateTime)
    # Placeholder - should be overridden by specific agent types
    return nothing
end

"""
    update_state!(agent::StateAgent, key::Symbol, value::Any)

Update agent state and record in history.
"""
function update_state!(agent::StateAgent, key::Symbol, value::Any)
    old_value = get(agent.state, key, nothing)
    agent.state[key] = value
    agent.updated_at = Dates.now()
    
    # Record in history
    push!(agent.history, (
        timestamp = agent.updated_at,
        action = :state_update,
        key = key,
        old_value = old_value,
        new_value = value
    ))
    
    return agent
end

"""
    add_connection!(agent::StateAgent, other_agent_id::UUID)

Add connection to another agent.
"""
function add_connection!(agent::StateAgent, other_agent_id::UUID)
    if !(other_agent_id in agent.connections)
        push!(agent.connections, other_agent_id)
    end
    return agent
end

"""
    remove_connection!(agent::StateAgent, other_agent_id::UUID)

Remove connection to another agent.
"""
function remove_connection!(agent::StateAgent, other_agent_id::UUID)
    filter!(id -> id != other_agent_id, agent.connections)
    return agent
end

"""
    record_interaction!(agent::StateAgent, interaction::NamedTuple)

Record an interaction in the agent's history.
"""
function record_interaction!(agent::StateAgent, interaction::NamedTuple)
    push!(agent.history, (
        timestamp = Dates.now(),
        action = :interaction,
        data = interaction
    ))
    
    # Limit history size
    if length(agent.history) > 10000
        agent.history = agent.history[end-5000:end]
    end
    
    return agent
end

"""
    update_integrity!(agent::StateAgent, factor::Float64)

Update the system integrity factor (OTSU parameter).
"""
function update_integrity!(agent::StateAgent, factor::Float64)
    @assert 0.0 <= factor <= 1.0 "Integrity factor must be between 0 and 1"
    agent.integrity_factor = factor
    agent.updated_at = Dates.now()
    return agent
end

"""
    add_emergence_property!(agent::StateAgent, property::Symbol)

Add an emergent property to the agent (OTSU parameter).
"""
function add_emergence_property!(agent::StateAgent, property::Symbol)
    if !(property in agent.emergence_properties)
        push!(agent.emergence_properties, property)
    end
    return agent
end

"""
    get_history(agent::StateAgent; 
                from_date::Union{Nothing, DateTime}=nothing,
                to_date::Union{Nothing, DateTime}=nothing,
                action_filter::Union{Nothing, Symbol}=nothing)

Filter agent history by date range and/or action type.
"""
function get_history(agent::StateAgent; 
                    from_date::Union{Nothing, DateTime}=nothing,
                    to_date::Union{Nothing, DateTime}=nothing,
                    action_filter::Union{Nothing, Symbol}=nothing)
    result = agent.history
    
    if from_date !== nothing
        result = filter(h -> h.timestamp >= from_date, result)
    end
    
    if to_date !== nothing
        result = filter(h -> h.timestamp <= to_date, result)
    end
    
    if action_filter !== nothing
        result = filter(h -> h.action == action_filter, result)
    end
    
    return result
end

"""
    clone_agent(agent::StateAgent)

Create a copy of the agent with a new ID.
"""
function clone_agent(agent::StateAgent)
    new_id = uuid4()
    cloned = StateAgent{agent.type}(new_id, agent.name, agent.system_level)
    cloned.state = copy(agent.state)
    cloned.connections = copy(agent.connections)
    cloned.emergence_properties = copy(agent.emergence_properties)
    cloned.integrity_factor = agent.integrity_factor
    cloned.behavior = agent.behavior
    return cloned
end

# Utility functions

"""
    agent_summary(agent::StateAgent)

Generate a summary of the agent's current state.
"""
function agent_summary(agent::StateAgent)
    return (
        id = agent.id,
        type = agent.type,
        name = agent.name,
        system_level = agent.system_level,
        state_keys = collect(keys(agent.state)),
        connections_count = length(agent.connections),
        history_size = length(agent.history),
        emergence_properties = agent.emergence_properties,
        integrity_factor = agent.integrity_factor,
        created_at = agent.created_at,
        updated_at = agent.updated_at
    )
end

export StateAgent, update_state!, add_connection!, remove_connection!
export record_interaction!, update_integrity!, add_emergence_property!
export get_history, clone_agent, agent_summary

end # module StateAgent
