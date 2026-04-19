# RegulatoryAgent.jl
# Модуль агентов контрольно-надзорных органов в области градостроительной деятельности РФ
# Реализует функции контроля, надзора и выдачи разрешительной документации

module RegulatoryAgent

using ..AgentTypes
using ..Lifecycle
using ..BIMManager
using Dates
using UUIDs

export RegulatoryType, RegulatoryAgent
export submit_for_expertise, apply_for_building_permit, perform_inspection
export commissioning_approval, issue_violation, check_permits
export get_permit_status, process_application, validate_documentation

"""
    @enum RegulatoryType

Перечисление типов контрольно-надзорных органов Российской Федерации
"""
@enum RegulatoryType begin
    STATE_CONSTRUCTION_SUPERVISION      # Ростехнадзор - Государственный строительный надзор (ГСН)
    STATE_EXPERTISE                     # Главгосэкспертиза / Региональные экспертизы
    LAND_AND_PROPERTY_CONTROL           # Росреестр - земельный контроль, кадастр, регистрация прав
    FIRE_SUPERVISION                    # Госпожнадзор (МЧС) - пожарный надзор
    ENVIRONMENTAL_SUPERVISION           # Росприроднадзор - экологический контроль, ОВОС
    LICENSING_AND_SRO_CONTROL           # Контроль допусков СРО, лицензирование
    MUNICIPAL_CONSTRUCTION_CONTROL      # Муниципальный земельный и строительный контроль
    UTILITY_COORDINATION                # Согласование с балансодержателями инженерных сетей
end

"""
    struct ViolationRecord

Запись о выявленном нарушении
"""
struct ViolationRecord
    id::UUID
    timestamp::DateTime
    regulatory_type::RegulatoryType
    project_id::String
    agent_id::String
    description::String
    severity::Symbol  # :minor, :major, :critical
    penalty_amount::Float64
    work_suspension::Bool
    deadline_for_correction::Union{Nothing, DateTime}
    status::Symbol  # :open, :in_progress, :resolved, :appealed
end

"""
    struct PermitRecord

Запись о выданном разрешении/заключении
"""
struct PermitRecord
    id::UUID
    permit_type::RegulatoryType
    project_id::String
    applicant_id::String
    issue_date::DateTime
    expiry_date::Union{Nothing, DateTime}
    document_reference::String  # Ссылка на документ в CDE
    conditions::Vector{String}  # Особые условия
    status::Symbol  # :active, :expired, :revoked, :suspended
end

"""
    struct RegulatoryApplication

Заявка на получение разрешения/согласования
"""
struct RegulatoryApplication
    id::UUID
    application_type::RegulatoryType
    project_id::String
    applicant_id::String
    submission_date::DateTime
    documents::Vector{String}  # Список документов в CDE
    model_reference::Union{Nothing, String}  # Ссылка на информационную модель
    status::Symbol  # :submitted, :under_review, :additional_info_required, :approved, :rejected
    review_comments::Vector{String}
    assigned_inspector::String
end

"""
    mutable struct RegulatoryAgent <: AbstractAgent

Агент контрольно-надзорного органа
"""
mutable struct RegulatoryAgent <: AbstractAgent
    id::String
    name::String
    regulatory_type::RegulatoryType
    jurisdiction_level::Symbol  # :federal, :regional, :municipal
    region_code::String
    
    # Реестры
    permits::Dict{String, PermitRecord}  # project_id -> PermitRecord
    violations::Dict{String, Vector{ViolationRecord}}  # project_id -> [ViolationRecord]
    applications::Dict{String, RegulatoryApplication}  # application_id -> RegulatoryApplication
    
    # Параметры работы
    processing_time_days::Int  # Среднее время рассмотрения заявок
    inspection_frequency_days::Int  # Частота плановых проверок
    strictness_factor::Float64  # Коэффициент строгости (0.0-1.0)
    
    # Статистика
    total_applications::Int
    approved_applications::Int
    rejected_applications::Int
    total_inspections::Int
    violations_detected::Int
    total_penalties::Float64
    
    # Состояние
    is_active::Bool
    created_at::DateTime
    last_activity::DateTime
end

"""
    RegulatoryAgent(; kwargs...)

Конструктор агента контрольно-надзорного органа
"""
function RegulatoryAgent(;
    name::String="",
    regulatory_type::RegulatoryType=STATE_EXPERTISE,
    jurisdiction_level::Symbol=:regional,
    region_code::String="77",
    processing_time_days::Int=30,
    inspection_frequency_days::Int=90,
    strictness_factor::Float64=0.5
)::RegulatoryAgent
    
    type_name = string(regulatory_type)
    agent_name = isempty(name) ? "$(type_name)_$(region_code)" : name
    
    return RegulatoryAgent(
        string(uuid4()),
        agent_name,
        regulatory_type,
        jurisdiction_level,
        region_code,
        Dict{String, PermitRecord}(),
        Dict{String, Vector{ViolationRecord}}(),
        Dict{String, RegulatoryApplication}(),
        processing_time_days,
        inspection_frequency_days,
        strictness_factor,
        0, 0, 0, 0, 0, 0.0,
        true,
        now(),
        now()
    )
end

# ============================================================================
# Функции взаимодействия с застройщиками и подрядчиками
# ============================================================================

"""
    submit_for_expertise(agent::RegulatoryAgent, project_id::String, 
                         applicant_id::String, documents::Vector{String},
                         model_ref::Union{Nothing, String}=nothing)::RegulatoryApplication

Подать заявку на государственную экспертизу проектной документации
"""
function submit_for_expertise(
    agent::RegulatoryAgent,
    project_id::String,
    applicant_id::String,
    documents::Vector{String},
    model_ref::Union{Nothing, String}=nothing
)::RegulatoryApplication
    
    if agent.regulatory_type != STATE_EXPERTISE
        error("Агент не является органом государственной экспертизы")
    end
    
    app_id = string(uuid4())
    application = RegulatoryApplication(
        UUID(app_id),
        agent.regulatory_type,
        project_id,
        applicant_id,
        now(),
        documents,
        model_ref,
        :submitted,
        String[],
        "inspector_$(rand(1:100))",
    )
    
    agent.applications[app_id] = application
    agent.total_applications += 1
    agent.last_activity = now()
    
    return application
end

"""
    apply_for_building_permit(agent::RegulatoryAgent, project_id::String,
                              applicant_id::String, documents::Vector{String}
                             )::RegulatoryApplication

Подать заявку на получение разрешения на строительство
"""
function apply_for_building_permit(
    agent::RegulatoryAgent,
    project_id::String,
    applicant_id::String,
    documents::Vector{String}
)::RegulatoryApplication
    
    if agent.regulatory_type != MUNICIPAL_CONSTRUCTION_CONTROL
        error("Агент не уполномочен выдавать разрешения на строительство")
    end
    
    app_id = string(uuid4())
    application = RegulatoryApplication(
        UUID(app_id),
        agent.regulatory_type,
        project_id,
        applicant_id,
        now(),
        documents,
        nothing,
        :submitted,
        String[],
        "inspector_$(rand(1:100))",
    )
    
    agent.applications[app_id] = application
    agent.total_applications += 1
    agent.last_activity = now()
    
    return application
end

"""
    process_application(agent::RegulatoryAgent, app_id::String,
                       current_model_status::Dict{String, Symbol}=Dict()
                       )::Tuple{Symbol, Vector{String}}

Обработать заявку на разрешение/согласование
Возвращает статус (:approved, :rejected, :additional_info_required) и комментарии
"""
function process_application(
    agent::RegulatoryAgent,
    app_id::String,
    current_model_status::Dict{String, Symbol}=Dict()
)::Tuple{Symbol, Vector{String}}
    
    if !haskey(agent.applications, app_id)
        error("Заявка с ID $app_id не найдена")
    end
    
    application = agent.applications[app_id]
    comments = String[]
    
    # Имитация процесса проверки
    # Вероятность выявления замечаний зависит от коэффициента строгости
    has_issues = rand() < agent.strictness_factor
    
    if has_issues
        # Генерация замечаний в зависимости от типа регулятора
        if application.application_type == STATE_EXPERTISE
            push!(comments, "Недостаточная глубина проработки раздела АР")
            push!(comments, "Отсутствуют расчеты по противопожарным мероприятиям")
            push!(comments, "Требуется уточнение данных инженерных изысканий")
        elseif application.application_type == FIRE_SUPERVISION
            push!(comments, "Не соблюдены требования к эвакуационным выходам")
            push!(comments, "Отсутствует проект систем пожаротушения")
        elseif application.application_type == ENVIRONMENTAL_SUPERVISION
            push!(comments, "Недостаточно мероприятий по охране окружающей среды")
            push!(comments, "Требуется корректировка раздела ОВОС")
        else
            push!(comments, "Выявлены несоответствия нормативным требованиям")
        end
        
        application.status = :additional_info_required
        application.review_comments = comments
        return (:additional_info_required, comments)
    else
        # Проверка полноты документов
        if length(application.documents) < 3
            push!(comments, "Неполный комплект документов")
            application.status = :additional_info_required
            application.review_comments = comments
            return (:additional_info_required, comments)
        end
        
        # Одобрение заявки
        application.status = :approved
        application.review_comments = ["Документация соответствует требованиям"]
        
        # Создание записи о разрешении
        permit_id = string(uuid4())
        permit = PermitRecord(
            UUID(permit_id),
            application.application_type,
            application.project_id,
            application.applicant_id,
            now(),
            now() + Day(365 * 2),  # Срок действия 2 года
            application.documents[1],
            String[],
            :active
        )
        
        agent.permits[application.project_id] = permit
        agent.approved_applications += 1
        
        return (:approved, ["Разрешение выдано"])
    end
end

"""
    perform_inspection(agent::RegulatoryAgent, project_id::String,
                      contractor_id::String, construction_stage::LifeCycleStage,
                      model_container::Union{Nothing, ModelElementContainer}=nothing
                      )::Vector{ViolationRecord}

Провести проверку объекта строительства
Возвращает список выявленных нарушений
"""
function perform_inspection(
    agent::RegulatoryAgent,
    project_id::String,
    contractor_id::String,
    construction_stage::LifeCycleStage,
    model_container::Union{Nothing, ModelElementContainer}=nothing
)::Vector{ViolationRecord}
    
    violations = ViolationRecord[]
    agent.total_inspections += 1
    
    # Вероятность выявления нарушений зависит от стадии и строгости
    base_probability = 0.3
    stage_factor = construction_stage in [CONSTRUCTION_WORKS, COMMISSIONING] ? 1.5 : 1.0
    violation_probability = base_probability * stage_factor * agent.strictness_factor
    
    if rand() < violation_probability
        # Генерация нарушения
        severity_roll = rand()
        severity = severity_roll < 0.7 ? :minor : (severity_roll < 0.9 ? :major : :critical)
        
        penalty = severity == :minor ? 50_000.0 : (severity == :major ? 300_000.0 : 1_000_000.0)
        suspend_works = severity in [:major, :critical]
        
        violation_descs = [
            "Нарушение требований технической безопасности",
            "Отклонение от проектной документации",
            "Некачественное выполнение работ",
            "Отсутствие исполнительной документации",
            "Нарушение сроков устранения предыдущих замечаний"
        ]
        
        violation = ViolationRecord(
            uuid4(),
            now(),
            agent.regulatory_type,
            project_id,
            contractor_id,
            violation_descs[rand(1:length(violation_descs))],
            severity,
            penalty,
            suspend_works,
            now() + Day(severity == :minor ? 14 : (severity == :major ? 7 : 1)),
            :open
        )
        
        push!(violations, violation)
        
        # Добавление в реестр нарушений
        if !haskey(agent.violations, project_id)
            agent.violations[project_id] = ViolationRecord[]
        end
        push!(agent.violations[project_id], violation)
        
        agent.violations_detected += 1
        agent.total_penalties += penalty
    end
    
    agent.last_activity = now()
    return violations
end

"""
    issue_violation(agent::RegulatoryAgent, project_id::String,
                   contractor_id::String, description::String,
                   severity::Symbol=:minor, penalty::Float64=0.0
                   )::ViolationRecord

Выдать предписание об устранении нарушения
"""
function issue_violation(
    agent::RegulatoryAgent,
    project_id::String,
    contractor_id::String,
    description::String,
    severity::Symbol=:minor,
    penalty::Float64=0.0
)::ViolationRecord
    
    if penalty == 0.0
        penalty = severity == :minor ? 50_000.0 : (severity == :major ? 300_000.0 : 1_000_000.0)
    end
    
    suspend_works = severity in [:major, :critical]
    
    violation = ViolationRecord(
        uuid4(),
        now(),
        agent.regulatory_type,
        project_id,
        contractor_id,
        description,
        severity,
        penalty,
        suspend_works,
        now() + Day(severity == :minor ? 14 : (severity == :major ? 7 : 1)),
        :open
    )
    
    if !haskey(agent.violations, project_id)
        agent.violations[project_id] = ViolationRecord[]
    end
    push!(agent.violations[project_id], violation)
    
    agent.violations_detected += 1
    agent.total_penalties += penalty
    agent.last_activity = now()
    
    return violation
end

"""
    commissioning_approval(agent::RegulatoryAgent, project_id::String,
                          applicant_id::String, documents::Vector{String},
                          model_ref::String
                          )::Tuple{Symbol, String}

Участие в комиссии по вводу объекта в эксплуатацию
Возвращает статус (:approved, :rejected) и комментарий
"""
function commissioning_approval(
    agent::RegulatoryAgent,
    project_id::String,
    applicant_id::String,
    documents::Vector{String},
    model_ref::String
)::Tuple{Symbol, String}
    
    # Проверка наличия активных нарушений
    if haskey(agent.violations, project_id)
        open_violations = filter(v -> v.status == :open, agent.violations[project_id])
        if !isempty(open_violations)
            return (:rejected, "Имеются неисполненные предписания: $(length(open_violations)) шт.")
        end
    end
    
    # Проверка наличия всех необходимых разрешений
    if !haskey(agent.permits, project_id)
        return (:rejected, "Отсутствует запись о выданном разрешении на строительство")
    end
    
    permit = agent.permits[project_id]
    if permit.status != :active
        return (:rejected, "Разрешение на строительство недействительно")
    end
    
    # Имитация проверки соответствия построенного объекта проекту
    if rand() < agent.strictness_factor * 0.2  # 20% вероятность замечаний при высокой строгости
        return (:rejected, "Выявлены отклонения от утвержденной проектной документации")
    end
    
    return (:approved, "Объект соответствует требованиям, готов к вводу в эксплуатацию")
end

"""
    check_permits(agent::RegulatoryAgent, project_id::String
                 )::Dict{RegulatoryType, Union{PermitRecord, Nothing}}

Проверить наличие всех необходимых разрешений для проекта
"""
function check_permits(agent::RegulatoryAgent, project_id::String
                      )::Dict{RegulatoryType, Union{PermitRecord, Nothing}}
    
    # Для данного агента проверяем только его тип разрешения
    result = Dict{RegulatoryType, Union{PermitRecord, Nothing}}()
    
    if haskey(agent.permits, project_id)
        result[agent.regulatory_type] = agent.permits[project_id]
    else
        result[agent.regulatory_type] = nothing
    end
    
    return result
end

"""
    get_permit_status(agent::RegulatoryAgent, project_id::String
                     )::Union{PermitRecord, Nothing}

Получить статус разрешения для проекта
"""
function get_permit_status(agent::RegulatoryAgent, project_id::String
                          )::Union{PermitRecord, Nothing}
    
    return get(agent.permits, project_id, nothing)
end

"""
    validate_documentation(agent::RegulatoryAgent, documents::Vector{String},
                          stage::LifeCycleStage
                          )::Tuple{Bool, Vector{String}}

Валидировать комплект документации для текущей стадии ЖЦ
"""
function validate_documentation(
    agent::RegulatoryAgent,
    documents::Vector{String},
    stage::LifeCycleStage
)::Tuple{Bool, Vector{String}}
    
    required_docs = Dict(
        PREDESIGN => ["ТЗ", "Отчет об изысканиях"],
        DESIGN => ["Пояснительная записка", "АР", "КР", "Инженерные разделы"],
        CONSTRUCTION_WORKS => ["РД", "ППР", "Исполнительная документация"],
        COMMISSIONING => ["АОР", "Исполнительная документация", "Паспорта оборудования"],
        OPERATION => ["Инструкции по эксплуатации", "Журналы обслуживания"]
    )
    
    stage_key = get(required_docs, stage, String[])
    
    if isempty(stage_key)
        return (true, ["Нет требований к документации для стадии $(stage)"])
    end
    
    missing_docs = setdiff(stage_key, documents)
    
    if isempty(missing_docs)
        return (true, ["Документация соответствует требованиям стадии"])
    else
        return (false, ["Отсутствуют документы: $(join(missing_docs, ", "))"])
    end
end

"""
    resolve_violation(agent::RegulatoryAgent, violation_id::UUID
                     )::Bool

Отметить нарушение как устраненное
"""
function resolve_violation(agent::RegulatoryAgent, violation_id::UUID)::Bool
    
    for (project_id, violations) in agent.violations
        for (idx, violation) in enumerate(violations)
            if violation.id == violation_id
                if violation.status == :open
                    agent.violations[project_id][idx] = ViolationRecord(
                        violation.id,
                        violation.timestamp,
                        violation.regulatory_type,
                        violation.project_id,
                        violation.agent_id,
                        violation.description,
                        violation.severity,
                        violation.penalty_amount,
                        violation.work_suspension,
                        violation.deadline_for_correction,
                        :resolved
                    )
                    return true
                end
                return false
            end
        end
    end
    
    return false
end

"""
    get_statistics(agent::RegulatoryAgent)::Dict{String, Any}

Получить статистику работы агента
"""
function get_statistics(agent::RegulatoryAgent)::Dict{String, Any}
    return Dict(
        "agent_id" => agent.id,
        "agent_name" => agent.name,
        "regulatory_type" => string(agent.regulatory_type),
        "jurisdiction" => string(agent.jurisdiction_level),
        "total_applications" => agent.total_applications,
        "approved_applications" => agent.approved_applications,
        "rejected_applications" => agent.rejected_applications,
        "approval_rate" => agent.total_applications > 0 ? 
            agent.approved_applications / agent.total_applications : 0.0,
        "total_inspections" => agent.total_inspections,
        "violations_detected" => agent.violations_detected,
        "total_penalties" => agent.total_penalties,
        "active_violations" => sum(
            count(v -> v.status == :open, violations) 
            for violations in values(agent.violations)
        ),
        "last_activity" => agent.last_activity
    )
end

end # module RegulatoryAgent
