"""
    Lifecycle

Implementation of lifecycle management based on GOST R 10.00.00.05 ESIM 
(Единая система информационного моделирования).

This module provides comprehensive lifecycle stage definitions, information model
management, and object lifecycle tracking for construction projects in accordance
with Russian BIM standards.

ГОСТ Р 10.00.00.05 определяет:
- Стадии жизненного цикла объекта капитального строительства
- Требования к информационной модели на каждой стадии
- Состав данных и документов
- Процессы обмена информацией между участниками
"""
module Lifecycle

using ..AgentTypes
using Dates
using UUIDs

# ============================================================================
# ENUMS: Расширенные стадии жизненного цикла по ГОСТ Р 10.00.00.05
# ============================================================================

@enum DetailedLifecycleStage begin
    # Предпроектная стадия (П)
    Stage_PreProjectPlanning      # П1 - Предпроектные предложения
    Stage_PreProjectAnalysis      # П2 - Анализ территории и условий
    Stage_PreProjectConcept       # П3 - Концептуальное проектирование
    
    # Проектирование (ПД)
    Stage_DesignAssignment        # Д1 - Задание на проектирование
    Stage_DesignPreliminary       # Д2 - Предпроектная документация
    Stage_DesignBasic             # Д3 - Основная проектная документация
    Stage_DesignDetailed          # Д4 - Рабочая документация
    Stage_DesignExpertise         # Д5 - Экспертиза проекта
    
    # Строительство (С)
    Stage_ConstructionPrep        # С1 - Подготовка к строительству
    Stage_ConstructionMain        # С2 - Основные строительно-монтажные работы
    Stage_ConstructionSpecial     # С3 - Специальные работы
    Stage_ConstructionCommissioning # С4 - Пусконаладочные работы
    
    # Ввод в эксплуатацию (В)
    Stage_CommissioningDocs       # В1 - Подготовка исполнительной документации
    Stage_CommissioningInspection # В2 - Проверка соответствия
    Stage_CommissioningPermit     # В3 - Получение разрешения на ввод
    Stage_CommissioningHandover   # В4 - Передача объекта эксплуатанту
    
    # Эксплуатация (Э)
    Stage_OperationNormal         # Э1 - Штатная эксплуатация
    Stage_OperationMaintenance    # Э2 - Техническое обслуживание
    Stage_OperationRepair         # Э3 - Текущий и капитальный ремонт
    Stage_OperationMonitoring     # Э4 - Мониторинг технического состояния
    
    # Реконструкция/Модернизация (Р)
    Stage_ReconstructionAnalysis  # Р1 - Анализ необходимости реконструкции
    Stage_ReconstructionDesign    # Р2 - Проектирование реконструкции
    Stage_ReconstructionWork      # Р3 - Выполнение работ по реконструкции
    
    # Завершение жизненного цикла (З)
    Stage_DecommissioningDecision # З1 - Решение о выводе из эксплуатации
    Stage_DecommissioningPrep     # З2 - Подготовка к ликвидации
    Stage_DecommissioningWork     # З3 - Ликвидация/снос объекта
    Stage_DecommissioningRecycle  # З4 - Утилизация материалов
end

# Категории информационной модели по ГОСТ
@enum InformationModelCategory begin
    Model_Architectural           # Архитектурные решения (АР)
    Model_Construction            # Конструктивные решения (КР)
    Model_Engineering             # Инженерные системы (ИС)
    Model_Technological           # Технологические решения (ТХ)
    Model_Schedule                # Календарное планирование (4D)
    Model_Cost                    # Сметное моделирование (5D)
    Model_Resources               # Управление ресурсами
    Model_Environment             # Экологический мониторинг
    Model_Integrated              # Сводная модель (federated model)
end

# Классификация объектов информационного моделирования по ГОСТ Р 10
@enum ObjectClassification begin
    Class_Industrial              # Промышленные объекты
    Class_Residential             # Жилые здания
    Class_Public                  # Общественные здания
    Class_Infrastructure          # Инфраструктурные объекты
    Class_Transport               # Транспортные сооружения
    Class_Energy                  # Энергетические объекты
    Class_Hydrotechnical          # Гидротехнические сооружения
    Class_Linear                  # Линейные объекты
    Class_Network                 # Сетевые объекты
    Class_Complex                 # Комплексы объектов
end

# Уровни информационной насыщенности (LOI - Level of Information)
@enum LevelOfInformation begin
    LOI_A  # Идентификационные данные
    LOI_B  # Технические характеристики
    LOI_C  # Эксплуатационные параметры
    LOI_D  # Данные производителя
    LOI_E  # Стоимость и ресурсы
    LOI_F  # Временные параметры (4D)
    LOI_G  # Экологические данные
end

# Статусы элемента модели в CDE
@enum ElementStatus begin
    Status_WIP           # Work in Progress - в разработке
    Status_Shared        # Готов к обмену
    Status_Published     # Утвержден
    Status_Archived      # Архивирован
end

# Типы изменений элемента
@enum ChangeType begin
    Change_Added         # Добавлен
    Change_Modified      # Изменен
    Change_Deleted       # Удален
    Change_StatusChanged # Изменен статус
    Change_PropertyChanged # Изменено свойство
end

# Статусы версии информационной модели
@enum ModelVersionStatus begin
    Status_WorkInProgress         # В разработке (WIP)
    Status_InternalReview         # На внутреннем согласовании
    Status_ExternalReview         # На внешнем согласовании
    Status_Approved               # Утверждена
    Status_AsBuilt                # Исполнительная модель
    Status_Archived               # Архивирована
    Status_Invalidated            # Утратила силу
end

# Уровни детализации (LOD - Level of Development)
@enum LevelOfDevelopment begin
    LOD_100  # Концептуальная модель
    LOD_200  # Приблизительная геометрия
    LOD_300  # Точная геометрия
    LOD_350  # Детализация для координации
    LOD_400  # Изготовительская детализация
    LOD_500  # Ас-билт модель
end

# Типы элементов информационной модели
@enum ModelElementType begin
    Element_Building              # Здание/сооружение
    Element_Structure             # Конструктивный элемент
    Element_Space                 # Помещение/пространство
    Element_System                # Инженерная система
    Element_Equipment             # Оборудование
    Element_Material              # Материал
    Element_Document              # Документ
    Element_Process               # Процесс/работа
end

# Связанный элемент модели
struct RelatedElement
    id::UUID
    relationship_type::Symbol  # :contains, :connected_to, :references, :similar_to
    description::String
end

# Значение параметра элемента
struct ParameterValue
    name::String
    value::Any
    unit::Union{Nothing, String}
    data_type::Symbol  # :string, :number, :boolean, :date, :reference
    source::Symbol  # :user, :calculated, :imported, :linked
end

# Данные геометрии элемента
struct GeometryData
    representation_type::Symbol  # :brep, :mesh, :csg, :parametric
    vertices::Vector{Tuple{Float64, Float64, Float64}}
    faces::Vector{Vector{Int}}
    bounding_box::NamedTuple{(:min, :max), Tuple{Tuple{Float64, Float64, Float64}, Tuple{Float64, Float64, Float64}}}
    volume::Union{Nothing, Float64}
    area::Union{Nothing, Float64}
end

# История изменений элемента
struct ElementChangeHistory
    element_id::UUID
    changes::Vector{NamedTuple{
        (:version, :date, :author, :change_type, :description, :old_value, :new_value),
        Tuple{String, Date, UUID, ChangeType, String, Any, Any}
    }}
    
    function ElementChangeHistory(element_id::UUID)
        changes = NamedTuple{
            (:version, :date, :author, :change_type, :description, :old_value, :new_value),
            Tuple{String, Date, UUID, ChangeType, String, Any, Any}
        }[]
        new(element_id, changes)
    end
end

# ============================================================================
# STRUCTS: Структуры данных жизненного цикла
# ============================================================================

"""
    LCObject

Представляет объект капитального строительства в контексте жизненного цикла.
"""
struct LCObject
    id::UUID
    name::String
    type::Symbol  # :building, :structure, :infrastructure, :linear_object
    category::String  # Классификация по ОКПД2
    location::NamedTuple{(:address, :coordinates, :cadastral_number), 
                         Tuple{String, Tuple{Float64, Float64}, String}}
    
    # Параметры объекта
    area::Float64  # Площадь, м²
    volume::Float64  # Объем, м³
    floors::Int
    construction_year::Union{Nothing, Int}
    
    # Ссылки на информационные модели
    models::Vector{UUID}
    
    # Текущая стадия ЖЦ
    current_stage::DetailedLifecycleStage
    stage_start_date::Date
    stage_planned_end::Date
    
    # Статусы
    status::Symbol  # :active, :suspended, :completed, :cancelled
    ownership::Symbol  # :state, :private, :mixed
    
    function LCObject(;
        name::String,
        type::Symbol,
        category::String,
        address::String,
        coordinates::Tuple{Float64, Float64} = (0.0, 0.0),
        cadastral_number::String = "",
        area::Real = 0.0,
        volume::Real = 0.0,
        floors::Int = 0,
        construction_year::Union{Nothing, Int} = nothing,
        current_stage::DetailedLifecycleStage = Stage_PreProjectPlanning,
        ownership::Symbol = :private
    )
        id = uuid1()
        models = UUID[]
        stage_start_date = today()
        stage_planned_end = today() + Year(1)
        status = :active
        
        location = (address = address, coordinates = coordinates, 
                   cadastral_number = cadastral_number)
        
        new(id, name, type, category, location, Float64(area), Float64(volume),
            floors, construction_year, models, current_stage, 
            stage_start_date, stage_planned_end, status, ownership)
    end
end

"""
    InformationModel

Информационная модель объекта капитального строительства по ГОСТ Р 10.
"""
struct InformationModel
    id::UUID
    object_id::UUID
    name::String
    category::InformationModelCategory
    lod::LevelOfDevelopment
    loi::LevelOfInformation  # Уровень информационной насыщенности
    
    # Версионирование
    version::String
    version_status::ModelVersionStatus
    previous_version::Union{Nothing, UUID}
    created_date::Date
    modified_date::Date
    
    # Авторство и ответственность
    author::UUID  # ID агента-разработчика
    responsible_party::UUID  # ID ответственной организации
    approvers::Vector{UUID}  # Список согласующих
    
    # Технические параметры
    file_format::String  # IFC, RVT, DWG, etc.
    file_size::Float64  # MB
    element_count::Int
    coordinate_system::String
    
    # Область применения
    applicable_stages::Vector{DetailedLifecycleStage}
    purpose::String
    
    # Проверки и валидация
    validation_status::Symbol  # :not_checked, :passed, :failed, :warnings
    validation_date::Union{Nothing, Date}
    clash_detected::Bool
    compliance_gost::Bool
    
    # Классификация объекта
    object_classification::ObjectClassification
    
    # Метаданные
    description::String
    keywords::Vector{String}
    external_references::Vector{String}  # Ссылки на документы, спецификации
    
    function InformationModel(;
        object_id::UUID,
        name::String,
        category::InformationModelCategory,
        lod::LevelOfDevelopment = LOD_200,
        loi::LevelOfInformation = LOI_B,
        version::String = "1.0",
        author::UUID,
        responsible_party::UUID,
        file_format::String = "IFC4",
        applicable_stages::Vector{DetailedLifecycleStage} = [],
        purpose::String = "",
        object_classification::ObjectClassification = Class_Complex
    )
        id = uuid1()
        version_status = Status_WorkInProgress
        previous_version = nothing
        created_date = today()
        modified_date = today()
        approvers = UUID[]
        file_size = 0.0
        element_count = 0
        coordinate_system = "МСК"
        validation_status = :not_checked
        validation_date = nothing
        clash_detected = false
        compliance_gost = true
        description = ""
        keywords = String[]
        external_references = String[]
        
        new(id, object_id, name, category, lod, loi, version, version_status,
            previous_version, created_date, modified_date, author,
            responsible_party, approvers, file_format, file_size, element_count,
            coordinate_system, applicable_stages, purpose, validation_status,
            validation_date, clash_detected, compliance_gost, object_classification,
            description, keywords, external_references)
    end
end

"""
    ModelVersionHistory

История версий информационной модели.
"""
struct ModelVersionHistory
    model_id::UUID
    versions::Vector{NamedTuple{
        (:version, :status, :date, :author, :changes, :comment),
        Tuple{String, ModelVersionStatus, Date, UUID, Vector{String}, String}
    }}
    
    function ModelVersionHistory(model_id::UUID)
        versions = NamedTuple{
            (:version, :status, :date, :author, :changes, :comment),
            Tuple{String, ModelVersionStatus, Date, UUID, Vector{String}, String}
        }[]
        new(model_id, versions)
    end
end

"""
    LCStageTransition

Переход между стадиями жизненного цикла.
"""
struct LCStageTransition
    from_stage::DetailedLifecycleStage
    to_stage::DetailedLifecycleStage
    transition_date::Date
    transition_reason::String
    
    # Требуемые документы для перехода
    required_documents::Vector{DocumentType}
    required_models::Vector{UUID}
    required_approvals::Vector{UUID}  # ID организаций для согласования
    
    # Фактические данные
    actual_documents::Vector{UUID}
    actual_approvals::Vector{UUID}
    transition_approved::Bool
    approval_date::Union{Nothing, Date}
    
    function LCStageTransition(
        from_stage::DetailedLifecycleStage,
        to_stage::DetailedLifecycleStage;
        reason::String = ""
    )
        transition_date = today()
        required_documents = DocumentType[]
        required_models = UUID[]
        required_approvals = UUID[]
        actual_documents = UUID[]
        actual_approvals = UUID[]
        transition_approved = false
        approval_date = nothing
        
        new(from_stage, to_stage, transition_date, reason,
            required_documents, required_models, required_approvals,
            actual_documents, actual_approvals, transition_approved, approval_date)
    end
end

"""
    LCProcess

Процесс жизненного цикла по ГОСТ Р 10.
"""
struct LCProcess
    id::UUID
    name::String
    stage::DetailedLifecycleStage
    process_type::Symbol  # :design, :construction, :approval, :operation, :maintenance
    
    # Параметры процесса
    planned_start::Date
    planned_duration::Int  # дней
    actual_start::Union{Nothing, Date}
    actual_finish::Union{Nothing, Date}
    
    # Ответственные
    responsible_agent::UUID
    participants::Vector{UUID}
    
    # Входы и выходы
    input_documents::Vector{UUID}
    input_models::Vector{UUID}
    output_documents::Vector{UUID}
    output_models::Vector{UUID}
    
    # Статус
    status::Symbol  # :planned, :in_progress, :completed, :suspended, :cancelled
    progress::Float64  # 0.0 - 1.0
    
    # Контрольные точки
    milestones::Vector{NamedTuple{
        (:name, :planned_date, :actual_date, :status),
        Tuple{String, Date, Union{Nothing, Date}, Symbol}
    }}
    
    function LCProcess(;
        name::String,
        stage::DetailedLifecycleStage,
        process_type::Symbol,
        planned_start::Date,
        planned_duration::Int,
        responsible_agent::UUID
    )
        id = uuid1()
        actual_start = nothing
        actual_finish = nothing
        participants = UUID[]
        input_documents = UUID[]
        input_models = UUID[]
        output_documents = UUID[]
        output_models = UUID[]
        status = :planned
        progress = 0.0
        milestones = NamedTuple{
            (:name, :planned_date, :actual_date, :status),
            Tuple{String, Date, Union{Nothing, Date}, Symbol}
        }[]
        
        new(id, name, stage, process_type, planned_start, planned_duration,
            actual_start, actual_finish, responsible_agent, participants,
            input_documents, input_models, output_documents, output_models,
            status, progress, milestones)
    end
end

"""
    LCStageRequirements

Требования к стадии жизненного цикла по ГОСТ Р 10.00.00.05.
"""
struct LCStageRequirements
    stage::DetailedLifecycleStage
    phase::Symbol  # :preproject, :design, :construction, :commissioning, :operation, :reconstruction, :decommissioning
    
    # Обязательные документы
    mandatory_documents::Vector{DocumentType}
    optional_documents::Vector{DocumentType}
    
    # Требования к информационным моделям
    required_model_categories::Vector{InformationModelCategory}
    minimum_lod::LevelOfDevelopment
    
    # Требуемые согласования
    required_approvals::Vector{Symbol}  # :expertise, :gosnadzor, :owner, etc.
    
    # Критерии завершения стадии
    completion_criteria::Vector{String}
    
    # Нормативные ссылки
    regulatory_references::Vector{String}
    
    function LCStageRequirements(stage::DetailedLifecycleStage)
        # Определение фазы
        phase = if stage in [Stage_PreProjectPlanning, Stage_PreProjectAnalysis, Stage_PreProjectConcept]
            :preproject
        elseif stage in [Stage_DesignAssignment, Stage_DesignPreliminary, Stage_DesignBasic, 
                        Stage_DesignDetailed, Stage_DesignExpertise]
            :design
        elseif stage in [Stage_ConstructionPrep, Stage_ConstructionMain, 
                        Stage_ConstructionSpecial, Stage_ConstructionCommissioning]
            :construction
        elseif stage in [Stage_CommissioningDocs, Stage_CommissioningInspection,
                        Stage_CommissioningPermit, Stage_CommissioningHandover]
            :commissioning
        elseif stage in [Stage_OperationNormal, Stage_OperationMaintenance,
                        Stage_OperationRepair, Stage_OperationMonitoring]
            :operation
        elseif stage in [Stage_ReconstructionAnalysis, Stage_ReconstructionDesign, Stage_ReconstructionWork]
            :reconstruction
        else
            :decommissioning
        end
        
        mandatory_documents = DocumentType[]
        optional_documents = DocumentType[]
        required_model_categories = InformationModelCategory[]
        minimum_lod = LOD_100
        required_approvals = Symbol[]
        completion_criteria = String[]
        regulatory_references = String[]
        
        new(stage, phase, mandatory_documents, optional_documents,
            required_model_categories, minimum_lod, required_approvals,
            completion_criteria, regulatory_references)
    end
end

"""
    AssetLifecycle

Полный жизненный цикл актива (объекта капитального строительства).
"""
mutable struct AssetLifecycle
    object_id::UUID
    object_name::String
    
    # История стадий
    stage_history::Vector{LCStageTransition}
    current_stage::DetailedLifecycleStage
    stage_entry_date::Date
    
    # Информационные модели
    models::Dict{UUID, InformationModel}
    model_history::Dict{UUID, ModelVersionHistory}
    
    # Процессы
    processes::Dict{UUID, LCProcess}
    
    # Документы
    documents::Dict{UUID, NamedTuple{
        (:type, :name, :stage, :status, :date, :author),
        Tuple{DocumentType, String, DetailedLifecycleStage, DocumentStatus, Date, UUID}
    }}
    
    # Требования по стадиям
    stage_requirements::Dict{DetailedLifecycleStage, LCStageRequirements}
    
    # Метрики жизненного цикла
    total_duration::Int  # дней
    planned_duration::Int
    cost_accumulated::Money
    budget_total::Money
    
    # Риски жизненного цикла
    risks::Vector{NamedTuple{
        (:id, :category, :description, :probability, :impact, :stage),
        Tuple{UUID, RiskCategory, String, Float64, Float64, DetailedLifecycleStage}
    }}
    
    function AssetLifecycle(object_id::UUID, object_name::String;
                           budget::Money = Money(0))
        stage_history = LCStageTransition[]
        current_stage = Stage_PreProjectPlanning
        stage_entry_date = today()
        models = Dict{UUID, InformationModel}()
        model_history = Dict{UUID, ModelVersionHistory}()
        processes = Dict{UUID, LCProcess}()
        documents = Dict{UUID, NamedTuple{
            (:type, :name, :stage, :status, :date, :author),
            Tuple{DocumentType, String, DetailedLifecycleStage, DocumentStatus, Date, UUID}
        }}()
        stage_requirements = Dict{DetailedLifecycleStage, LCStageRequirements}()
        total_duration = 0
        planned_duration = 0
        cost_accumulated = Money(0)
        budget_total = budget
        risks = NamedTuple{
            (:id, :category, :description, :probability, :impact, :stage),
            Tuple{UUID, RiskCategory, String, Float64, Float64, DetailedLifecycleStage}
        }[]
        
        new(object_id, object_name, stage_history, current_stage, stage_entry_date,
            models, model_history, processes, documents, stage_requirements,
            total_duration, planned_duration, cost_accumulated, budget_total, risks)
    end
end

# ============================================================================
# FUNCTIONS: Операции жизненного цикла
# ============================================================================

"""
    get_phase_for_stage(stage::DetailedLifecycleStage)::Symbol

Возвращает укрупненную фазу для детальной стадии ЖЦ.
"""
function get_phase_for_stage(stage::DetailedLifecycleStage)::Symbol
    if stage in [Stage_PreProjectPlanning, Stage_PreProjectAnalysis, Stage_PreProjectConcept]
        return :preproject
    elseif stage in [Stage_DesignAssignment, Stage_DesignPreliminary, Stage_DesignBasic, 
                    Stage_DesignDetailed, Stage_DesignExpertise]
        return :design
    elseif stage in [Stage_ConstructionPrep, Stage_ConstructionMain, 
                    Stage_ConstructionSpecial, Stage_ConstructionCommissioning]
        return :construction
    elseif stage in [Stage_CommissioningDocs, Stage_CommissioningInspection,
                    Stage_CommissioningPermit, Stage_CommissioningHandover]
        return :commissioning
    elseif stage in [Stage_OperationNormal, Stage_OperationMaintenance,
                    Stage_OperationRepair, Stage_OperationMonitoring]
        return :operation
    elseif stage in [Stage_ReconstructionAnalysis, Stage_ReconstructionDesign, Stage_ReconstructionWork]
        return :reconstruction
    else
        return :decommissioning
    end
end

"""
    get_required_documents(stage::DetailedLifecycleStage)::Vector{DocumentType}

Возвращает список обязательных документов для стадии по ГОСТ Р 10.
"""
function get_required_documents(stage::DetailedLifecycleStage)::Vector{DocumentType}
    docs = DocumentType[]
    
    if stage in [Stage_PreProjectPlanning, Stage_PreProjectAnalysis, Stage_PreProjectConcept]
        push!(docs, DocumentType.GPZU, DocumentType.LandDocument)
    elseif stage == Stage_DesignAssignment
        push!(docs, DocumentType.ProjectDocumentation)
    elseif stage in [Stage_DesignBasic, Stage_DesignDetailed]
        push!(docs, DocumentType.ProjectDocumentation, DocumentType.ExpertConclusion)
    elseif stage == Stage_DesignExpertise
        push!(docs, DocumentType.ExpertConclusion)
    elseif stage == Stage_ConstructionPrep
        push!(docs, DocumentType.ConstructionPermit)
    elseif stage in [Stage_CommissioningDocs, Stage_CommissioningInspection]
        # Исполнительная документация
    elseif stage == Stage_CommissioningPermit
        push!(docs, DocumentType.CommissioningPermit, DocumentType.TechnicalPlan)
    elseif stage == Stage_CommissioningHandover
        push!(docs, DocumentType.ActOfAcceptance)
    end
    
    return docs
end

"""
    get_required_models(stage::DetailedLifecycleStage)::Vector{InformationModelCategory}

Возвращает требуемые категории информационных моделей для стадии.
"""
function get_required_models(stage::DetailedLifecycleStage)::Vector{InformationModelCategory}
    models = InformationModelCategory[]
    
    if stage in [Stage_PreProjectConcept, Stage_DesignPreliminary]
        push!(models, Model_Architectural, Model_Construction)
    elseif stage in [Stage_DesignBasic, Stage_DesignDetailed]
        push!(models, Model_Architectural, Model_Construction, Model_Engineering, 
              Model_Technological, Model_Schedule, Model_Cost)
    elseif stage in [Stage_ConstructionMain, Stage_ConstructionSpecial]
        push!(models, Model_Construction, Model_Engineering, Model_Resources, Model_Schedule)
    elseif stage in [Stage_CommissioningDocs, Stage_CommissioningHandover]
        push!(models, Model_Integrated)
    elseif stage in [Stage_OperationNormal, Stage_OperationMaintenance]
        push!(models, Model_Integrated, Model_Engineering, Model_Environment)
    end
    
    return models
end

"""
    get_minimum_lod(stage::DetailedLifecycleStage)::LevelOfDevelopment

Возвращает минимальный уровень детализации (LOD) для стадии.
"""
function get_minimum_lod(stage::DetailedLifecycleStage)::LevelOfDevelopment
    if stage in [Stage_PreProjectPlanning, Stage_PreProjectAnalysis]
        return LOD_100
    elseif stage == Stage_PreProjectConcept || stage == Stage_DesignPreliminary
        return LOD_200
    elseif stage in [Stage_DesignBasic, Stage_DesignDetailed]
        return LOD_300
    elseif stage in [Stage_ConstructionPrep, Stage_ConstructionMain]
        return LOD_350
    elseif stage in [Stage_ConstructionSpecial, Stage_ConstructionCommissioning]
        return LOD_400
    elseif stage in [Stage_CommissioningDocs, Stage_CommissioningHandover]
        return LOD_500
    elseif stage in [Stage_OperationNormal, Stage_OperationMaintenance]
        return LOD_500
    else
        return LOD_200
    end
end

"""
    create_lifecycle(object::LCObject)::AssetLifecycle

Создает структуру жизненного цикла для объекта.
"""
function create_lifecycle(object::LCObject)::AssetLifecycle
    lifecycle = AssetLifecycle(object.id, object.name)
    
    # Инициализация требований по стадиям
    for stage in instances(DetailedLifecycleStage)
        requirements = LCStageRequirements(stage)
        requirements.mandatory_documents = get_required_documents(stage)
        requirements.required_model_categories = get_required_models(stage)
        requirements.minimum_lod = get_minimum_lod(stage)
        
        # Добавление критериев завершения
        criteria = generate_completion_criteria(stage)
        requirements.completion_criteria = criteria
        
        # Нормативные ссылки
        requirements.regulatory_references = generate_regulatory_refs(stage)
        
        lifecycle.stage_requirements[stage] = requirements
    end
    
    return lifecycle
end

"""
    generate_completion_criteria(stage::DetailedLifecycleStage)::Vector{String}

Генерирует критерии завершения стадии.
"""
function generate_completion_criteria(stage::DetailedLifecycleStage)::Vector{String}
    criteria = String[]
    
    if stage == Stage_PreProjectConcept
        push!(criteria, "Концепция утверждена заказчиком")
        push!(criteria, "Проведен анализ технико-экономических показателей")
    elseif stage == Stage_DesignExpertise
        push!(criteria, "Получено положительное заключение экспертизы")
        push!(criteria, "Устранены замечания экспертизы")
    elseif stage == Stage_ConstructionPrep
        push!(criteria, "Получено разрешение на строительство")
        push!(criteria, "Подписан договор подряда")
        push!(criteria, "Организована строительная площадка")
    elseif stage == Stage_CommissioningPermit
        push!(criteria, "Получено разрешение на ввод в эксплуатацию")
        push!(criteria, "Подписан акт приема-передачи")
    elseif stage == Stage_OperationNormal
        push!(criteria, "Объект эксплуатируется в штатном режиме")
        push!(criteria, "Отсутствуют критические дефекты")
    end
    
    return criteria
end

"""
    generate_regulatory_refs(stage::DetailedLifecycleStage)::Vector{String}

Генерирует нормативные ссылки для стадии.
"""
function generate_regulatory_refs(stage::DetailedLifecycleStage)::Vector{String}
    refs = String[]
    
    # Базовые нормативы
    push!(refs, "Градостроительный кодекс РФ")
    push!(refs, "ГОСТ Р 10.00.00.05-2020 ЕСИМ")
    
    if stage in [Stage_DesignBasic, Stage_DesignDetailed, Stage_DesignExpertise]
        push!(refs, "Постановление Правительства РФ №87")
        push!(refs, "ГОСТ Р 21.1101-2013")
    elseif stage in [Stage_ConstructionMain, Stage_ConstructionSpecial]
        push!(refs, "СП 48.13330.2019 Организация строительства")
        push!(refs, "ГОСТ Р 10.02.00.02-2020")
    elseif stage in [Stage_CommissioningPermit, Stage_CommissioningHandover]
        push!(refs, "Статья 55 Градостроительного кодекса РФ")
    elseif stage in [Stage_OperationNormal, Stage_OperationMaintenance]
        push!(refs, "ГОСТ Р 10.03.00.03-2020 Эксплуатация объектов")
    end
    
    return refs
end

"""
    advance_stage!(lifecycle::AssetLifecycle, new_stage::DetailedLifecycleStage;
                   reason::String = "")::Bool

Переводит жизненный цикл на новую стадию.
"""
function advance_stage!(lifecycle::AssetLifecycle, new_stage::DetailedLifecycleStage;
                       reason::String = "")::Bool
    old_stage = lifecycle.current_stage
    
    # Проверка возможности перехода
    if !is_valid_transition(old_stage, new_stage)
        @warn "Недопустимый переход со стадии $old_stage на $new_stage"
        return false
    end
    
    # Проверка выполнения требований текущей стадии
    requirements = get(lifecycle.stage_requirements, old_stage, nothing)
    if requirements !== nothing
        if !check_stage_completion(lifecycle, old_stage)
            @warn "Стадия $old_stage не завершена. Критерии не выполнены."
            return false
        end
    end
    
    # Создание записи о переходе
    transition = LCStageTransition(old_stage, new_stage, reason = reason)
    push!(lifecycle.stage_history, transition)
    
    # Обновление текущего состояния
    lifecycle.current_stage = new_stage
    lifecycle.stage_entry_date = today()
    
    return true
end

"""
    is_valid_transition(from::DetailedLifecycleStage, to::DetailedLifecycleStage)::Bool

Проверяет допустимость перехода между стадиями.
"""
function is_valid_transition(from::DetailedLifecycleStage, to::DetailedLifecycleStage)::Bool
    # Прямой порядок стадий
    stages_ordered = instances(DetailedLifecycleStage) |> collect
    
    from_idx = findfirst(==(from), stages_ordered)
    to_idx = findfirst(==(to), stages_ordered)
    
    if from_idx === nothing || to_idx === nothing
        return false
    end
    
    # Разрешаем переход вперед на 1-2 стадии или возврат на предыдущую
    if to_idx > from_idx && to_idx <= from_idx + 3
        return true
    end
    
    # Возврат на одну стадию назад возможен при выявлении проблем
    if to_idx == from_idx - 1
        return true
    end
    
    # Особые случаи (например, переход на реконструкцию из эксплуатации)
    if from in [Stage_OperationNormal, Stage_OperationMonitoring] &&
       to == Stage_ReconstructionAnalysis
        return true
    end
    
    return false
end

"""
    check_stage_completion(lifecycle::AssetLifecycle, stage::DetailedLifecycleStage)::Bool

Проверяет выполнение критериев завершения стадии.
"""
function check_stage_completion(lifecycle::AssetLifecycle, stage::DetailedLifecycleStage)::Bool
    requirements = get(lifecycle.stage_requirements, stage, nothing)
    if requirements === nothing
        return true
    end
    
    # Проверка наличия обязательных документов
    for doc_type in requirements.mandatory_documents
        found = false
        for (_, doc) in lifecycle.documents
            if doc.type == doc_type && doc.status in [:Approved, :Submitted]
                found = true
                break
            end
        end
        if !found
            return false
        end
    end
    
    # Проверка наличия требуемых моделей
    required_models = get_required_models(stage)
    for model_cat in required_models
        found = false
        for (_, model) in lifecycle.models
            if model.category == model_cat && 
               model.version_status in [Status_Approved, Status_AsBuilt]
                found = true
                break
            end
        end
        if !found
            return false
        end
    end
    
    return true
end

"""
    add_model!(lifecycle::AssetLifecycle, model::InformationModel)

Добавляет информационную модель в жизненный цикл.
"""
function add_model!(lifecycle::AssetLifecycle, model::InformationModel)
    lifecycle.models[model.id] = model
    lifecycle.model_history[model.id] = ModelVersionHistory(model.id)
    
    # Добавление первой версии в историю
    version_record = (
        version = model.version,
        status = model.version_status,
        date = model.created_date,
        author = model.author,
        changes = ["Initial version"],
        comment = ""
    )
    push!(lifecycle.model_history[model.id].versions, version_record)
end

"""
    update_model_version!(lifecycle::AssetLifecycle, model_id::UUID, 
                          new_version::String, changes::Vector{String};
                          author::UUID)::InformationModel

Создает новую версию информационной модели.
"""
function update_model_version!(lifecycle::AssetLifecycle, model_id::UUID, 
                               new_version::String, changes::Vector{String};
                               author::UUID)::Union{InformationModel, Nothing}
    old_model = get(lifecycle.models, model_id, nothing)
    if old_model === nothing
        return nothing
    end
    
    # Сохранение текущей версии в историю
    history = lifecycle.model_history[model_id]
    version_record = (
        version = old_model.version,
        status = old_model.version_status,
        date = old_model.modified_date,
        author = old_model.author,
        changes = changes,
        comment = "Updated to version $new_version"
    )
    push!(history.versions, version_record)
    
    # Создание новой версии модели
    new_model = InformationModel(
        object_id = old_model.object_id,
        name = old_model.name,
        category = old_model.category,
        lod = old_model.lod,
        version = new_version,
        author = author,
        responsible_party = old_model.responsible_party,
        file_format = old_model.file_format,
        applicable_stages = old_model.applicable_stages,
        purpose = old_model.purpose
    )
    new_model.previous_version = model_id
    
    # Обновление в словаре
    lifecycle.models[model_id] = new_model
    
    return new_model
end

"""
    add_document!(lifecycle::AssetLifecycle, doc_type::DocumentType, 
                  name::String, author::UUID; 
                  status::DocumentStatus = Draft)

Добавляет документ в жизненный цикл.
"""
function add_document!(lifecycle::AssetLifecycle, doc_type::DocumentType, 
                      name::String, author::UUID; 
                      status::DocumentStatus = Draft)::UUID
    doc_id = uuid1()
    doc_data = (
        type = doc_type,
        name = name,
        stage = lifecycle.current_stage,
        status = status,
        date = today(),
        author = author
    )
    lifecycle.documents[doc_id] = doc_data
    return doc_id
end

"""
    add_process!(lifecycle::AssetLifecycle, process::LCProcess)

Добавляет процесс в жизненный цикл.
"""
function add_process!(lifecycle::AssetLifecycle, process::LCProcess)
    lifecycle.processes[process.id] = process
end

"""
    get_lifecycle_metrics(lifecycle::AssetLifecycle)::NamedTuple

Возвращает метрики жизненного цикла.
"""
function get_lifecycle_metrics(lifecycle::AssetLifecycle)::NamedTuple{
    (:current_stage, :total_stages_completed, :duration_days, :budget_utilization,
     :document_count, :model_count, :process_count, :risk_count),
    Tuple{DetailedLifecycleStage, Int, Int, Float64, Int, Int, Int, Int}
}
    stages_completed = length(lifecycle.stage_history)
    duration_days = Dates.value(today() - lifecycle.stage_entry_date)
    budget_util = lifecycle.cost_accumulated.amount / max(lifecycle.budget_total.amount, 1) * 100
    doc_count = length(lifecycle.documents)
    model_count = length(lifecycle.models)
    process_count = length(lifecycle.processes)
    risk_count = length(lifecycle.risks)
    
    return (
        current_stage = lifecycle.current_stage,
        total_stages_completed = stages_completed,
        duration_days = duration_days,
        budget_utilization = budget_util,
        document_count = doc_count,
        model_count = model_count,
        process_count = process_count,
        risk_count = risk_count
    )
end

"""
    export_lifecycle_report(lifecycle::AssetLifecycle)::String

Формирует отчет по жизненному циклу.
"""
function export_lifecycle_report(lifecycle::AssetLifecycle)::String
    metrics = get_lifecycle_metrics(lifecycle)
    
    report = """
    # Отчет по жизненному циклу объекта
    ## $(lifecycle.object_name)
    
    **Текущая стадия:** $(lifecycle.current_stage)
    **Дата входа в стадию:** $(lifecycle.stage_entry_date)
    
    ### Метрики
    - Стадий пройдено: $(metrics.total_stages_completed)
    - Длительность (дней): $(metrics.duration_days)
    - Использование бюджета: $(round(metrics.budget_utilization, digits=2))%
    - Документов: $(metrics.document_count)
    - Информационных моделей: $(metrics.model_count)
    - Активных процессов: $(metrics.process_count)
    - Выявленных рисков: $(metrics.risk_count)
    
    ### История стадий
    """
    
    for transition in lifecycle.stage_history
        report *= "\n- $(transition.from_stage) → $(transition.to_stage) ($(transition.transition_date))"
        if !isempty(transition.transition_reason)
            report *= ": $(transition.transition_reason)"
        end
    end
    
    report *= "\n\n### Информационные модели\n"
    for (id, model) in lifecycle.models
        report *= "\n- $(model.name) (v$(model.version), LOD: $(model.lod), статус: $(model.version_status))"
    end
    
    return report
end

export DetailedLifecycleStage, InformationModelCategory, ModelVersionStatus
export LevelOfDevelopment, ModelElementType, ObjectClassification
export LevelOfInformation, ElementStatus, ChangeType
export RelatedElement, ParameterValue, GeometryData, ElementChangeHistory
export LCObject, InformationModel, ModelVersionHistory, LCStageTransition
export LCProcess, LCStageRequirements, AssetLifecycle
export get_phase_for_stage, get_required_documents, get_required_models
export get_minimum_lod, create_lifecycle, advance_stage!
export is_valid_transition, check_stage_completion, add_model!
export update_model_version!, add_document!, add_process!
export get_lifecycle_metrics, export_lifecycle_report

end # module Lifecycle
