"""
    ModelElementManager

Модуль управления элементами информационной модели по ГОСТ Р 10.00.00.05 ЕСИМ.

Обеспечивает:
- Создание и управление элементами модели
- Управление связями между элементами
- Контроль версий элементов
- Валидацию элементов по требованиям стадии
- Экспорт/импорт элементов
"""
module ModelElementManager

using ..Lifecycle
using UUIDs
using Dates

# ============================================================================
# STRUCTS: Элементы информационной модели
# ============================================================================

"""
    ModelElement

Элемент информационной модели объекта капитального строительства.
Соответствует требованиям ГОСТ Р 10 к структуре данных элемента.
"""
mutable struct ModelElement
    id::UUID
    guid::String  # Globally Unique Identifier по IFC
    name::String
    type::ModelElementType
    classification::String  # Код по классификатору (ОКПД2, КСФ)
    
    # Геометрия
    geometry::Union{Nothing, GeometryData}
    lod::LevelOfDevelopment
    loi::LevelOfInformation
    
    # Информация (LOI)
    attributes::Dict{String, Any}
    parameters::Dict{String, ParameterValue}
    
    # Связи
    parent::Union{Nothing, UUID}
    children::Vector{UUID}
    related_elements::Vector{RelatedElement}
    
    # Документы
    attached_documents::Vector{UUID}
    
    # Статусы
    status::ElementStatus
    created_date::Date
    modified_date::Date
    author::UUID
    
    # Стадии присутствия
    stages_present::Vector{DetailedLifecycleStage}
    
    # История изменений
    change_history::ElementChangeHistory
    
    function ModelElement(;
        name::String,
        type::ModelElementType,
        classification::String = "",
        lod::LevelOfDevelopment = LOD_200,
        loi::LevelOfInformation = LOI_B,
        author::UUID,
        parent::Union{Nothing, UUID} = nothing,
        stages_present::Vector{DetailedLifecycleStage} = DetailedLifecycleStage[]
    )
        id = uuid1()
        guid = generate_ifc_guid()
        geometry = nothing
        attributes = Dict{String, Any}()
        parameters = Dict{String, ParameterValue}()
        children = UUID[]
        related_elements = RelatedElement[]
        attached_documents = UUID[]
        status = Status_WIP
        created_date = today()
        modified_date = today()
        
        if isempty(stages_present)
            push!(stages_present, Stage_PreProjectPlanning)
        end
        
        change_history = ElementChangeHistory(id)
        
        new(id, guid, name, type, classification, geometry, lod, loi,
            attributes, parameters, parent, children, related_elements,
            attached_documents, status, created_date, modified_date, author,
            stages_present, change_history)
    end
end

"""
    ModelElementContainer

Контейнер для хранения и организации элементов модели.
"""
struct ModelElementContainer
    id::UUID
    name::String
    model_id::UUID
    elements::Dict{UUID, ModelElement}
    root_elements::Vector{UUID}
    
    # Индексы для быстрого поиска
    by_type::Dict{ModelElementType, Vector{UUID}}
    by_classification::Dict{String, Vector{UUID}}
    by_stage::Dict{DetailedLifecycleStage, Vector{UUID}}
    
    function ModelElementContainer(model_id::UUID, name::String = "Elements")
        id = uuid1()
        elements = Dict{UUID, ModelElement}()
        root_elements = UUID[]
        by_type = Dict{ModelElementType, Vector{UUID}}()
        by_classification = Dict{String, Vector{UUID}}()
        by_stage = Dict{DetailedLifecycleStage, Vector{UUID}}()
        
        new(id, name, model_id, elements, root_elements, 
            by_type, by_classification, by_stage)
    end
end

"""
    ElementValidationResult

Результат валидации элемента модели.
"""
struct ElementValidationResult
    element_id::UUID
    validation_date::Date
    is_valid::Bool
    
    # Проверки
    geometry_valid::Bool
    lod_valid::Bool
    loi_valid::Bool
    classification_valid::Bool
    required_parameters_present::Bool
    
    # Ошибки и предупреждения
    errors::Vector{String}
    warnings::Vector{String}
    
    function ElementValidationResult(element_id::UUID)
        id = element_id
        validation_date = today()
        is_valid = true
        geometry_valid = true
        lod_valid = true
        loi_valid = true
        classification_valid = true
        required_parameters_present = true
        errors = String[]
        warnings = String[]
        
        new(id, validation_date, is_valid, geometry_valid, lod_valid, 
            loi_valid, classification_valid, required_parameters_present,
            errors, warnings)
    end
end

# ============================================================================
# FUNCTIONS: Генерация идентификаторов
# ============================================================================

"""
    generate_ifc_guid()::String

Генерирует GUID в формате IFC (22 символа).
"""
function generate_ifc_guid()::String
    chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_\$"
    result = ""
    for i in 1:22
        idx = rand(1:length(chars))
        result *= chars[idx]
    end
    return result
end

# ============================================================================
# FUNCTIONS: Операции с элементами
# ============================================================================

"""
    add_element!(container::ModelElementContainer, element::ModelElement)

Добавляет элемент в контейнер.
"""
function add_element!(container::ModelElementContainer, element::ModelElement)
    container.elements[element.id] = element
    
    # Добавление в индекс по типу
    if !haskey(container.by_type, element.type)
        container.by_type[element.type] = UUID[]
    end
    push!(container.by_type[element.type], element.id)
    
    # Добавление в индекс по классификации
    if !isempty(element.classification)
        if !haskey(container.by_classification, element.classification)
            container.by_classification[element.classification] = UUID[]
        end
        push!(container.by_classification[element.classification], element.id)
    end
    
    # Добавление в индекс по стадиям
    for stage in element.stages_present
        if !haskey(container.by_stage, stage)
            container.by_stage[stage] = UUID[]
        end
        push!(container.by_stage[stage], element.id)
    end
    
    # Добавление к родительскому элементу
    if element.parent !== nothing
        parent = get(container.elements, element.parent, nothing)
        if parent !== nothing
            push!(parent.children, element.id)
        end
    else
        push!(container.root_elements, element.id)
    end
    
    # Запись в историю изменений
    add_change_record!(element.change_history, "1.0", Change_Added, 
                      "Element created", nothing, nothing, element.author)
end

"""
    add_child_element!(container::ModelElementContainer, 
                       parent_id::UUID, element::ModelElement)

Добавляет дочерний элемент к родителю.
"""
function add_child_element!(container::ModelElementContainer, 
                           parent_id::UUID, element::ModelElement)
    element.parent = parent_id
    add_element!(container, element)
end

"""
    add_parameter!(element::ModelElement, param::ParameterValue)

Добавляет параметр к элементу.
"""
function add_parameter!(element::ModelElement, param::ParameterValue)
    old_value = get(element.parameters, param.name, nothing)
    element.parameters[param.name] = param
    element.modified_date = today()
    
    add_change_record!(element.change_history, 
                      element.lod == LOD_100 ? "1.0" : "1.1",
                      Change_PropertyChanged,
                      "Parameter $(param.name) added/modified",
                      old_value, param, element.author)
end

"""
    set_geometry!(element::ModelElement, geometry::GeometryData)

Устанавливает геометрию элемента.
"""
function set_geometry!(element::ModelElement, geometry::GeometryData)
    old_geometry = element.geometry
    element.geometry = geometry
    element.modified_date = today()
    
    add_change_record!(element.change_history, "1.0", Change_Modified,
                      "Geometry updated", old_geometry, geometry, element.author)
end

"""
    update_element_status!(element::ModelElement, new_status::ElementStatus)

Обновляет статус элемента в CDE.
"""
function update_element_status!(element::ModelElement, new_status::ElementStatus)
    old_status = element.status
    element.status = new_status
    element.modified_date = today()
    
    add_change_record!(element.change_history, "1.0", Change_StatusChanged,
                      "Status changed from $old_status to $new_status",
                      old_status, new_status, element.author)
end

"""
    add_related_element!(element::ModelElement, related_id::UUID,
                         relationship_type::Symbol, description::String = "")

Добавляет связь с другим элементом.
"""
function add_related_element!(element::ModelElement, related_id::UUID,
                             relationship_type::Symbol, description::String = "")
    relation = RelatedElement(related_id, relationship_type, description)
    push!(element.related_elements, relation)
    element.modified_date = today()
end

# ============================================================================
# FUNCTIONS: История изменений
# ============================================================================

"""
    add_change_record!(history::ElementChangeHistory, version::String,
                       change_type::ChangeType, description::String,
                       old_value::Any, new_value::Any, author::UUID)

Добавляет запись об изменении в историю.
"""
function add_change_record!(history::ElementChangeHistory, version::String,
                           change_type::ChangeType, description::String,
                           old_value::Any, new_value::Any, author::UUID)
    record = (
        version = version,
        date = today(),
        author = author,
        change_type = change_type,
        description = description,
        old_value = old_value,
        new_value = new_value
    )
    push!(history.changes, record)
end

"""
    get_change_history(element::ModelElement)::Vector

Возвращает историю изменений элемента.
"""
function get_change_history(element::ModelElement)::Vector
    return element.change_history.changes
end

# ============================================================================
# FUNCTIONS: Валидация элементов
# ============================================================================

"""
    validate_element(element::ModelElement, 
                    required_lod::LevelOfDevelopment,
                    required_loi::LevelOfInformation,
                    required_params::Vector{String} = []
                    )::ElementValidationResult

Выполняет валидацию элемента по требованиям.
"""
function validate_element(element::ModelElement, 
                         required_lod::LevelOfDevelopment,
                         required_loi::LevelOfInformation,
                         required_params::Vector{String} = []
                         )::ElementValidationResult
    result = ElementValidationResult(element.id)
    
    # Проверка LOD
    lod_values = Dict(
        LOD_100 => 1, LOD_200 => 2, LOD_300 => 3, 
        LOD_350 => 4, LOD_400 => 5, LOD_500 => 6
    )
    if get(lod_values, element.lod, 0) < get(lod_values, required_lod, 0)
        result.lod_valid = false
        result.is_valid = false
        push!(result.errors, "LOD элемента ($(element.lod)) ниже требуемого ($required_lod)")
    end
    
    # Проверка LOI
    loi_values = Dict(LOI_A => 1, LOI_B => 2, LOI_C => 3, LOI_D => 4, 
                     LOI_E => 5, LOI_F => 6, LOI_G => 7)
    if get(loi_values, element.loi, 0) < get(loi_values, required_loi, 0)
        result.loi_valid = false
        result.is_valid = false
        push!(result.errors, "LOI элемента ($(element.loi)) ниже требуемого ($required_loi)")
    end
    
    # Проверка геометрии
    if element.lod >= LOD_200 && element.geometry === nothing
        result.geometry_valid = false
        result.is_valid = false
        push!(result.errors, "Отсутствует геометрия для LOD $(element.lod)")
    end
    
    # Проверка классификации
    if isempty(element.classification)
        result.classification_valid = false
        push!(result.warnings, "Не указана классификация элемента")
    end
    
    # Проверка обязательных параметров
    for param_name in required_params
        if !haskey(element.parameters, param_name)
            result.required_parameters_present = false
            result.is_valid = false
            push!(result.errors, "Отсутствует обязательный параметр: $param_name")
        end
    end
    
    return result
end

"""
    validate_container_by_stage(container::ModelElementContainer,
                                stage::DetailedLifecycleStage
                                )::Vector{ElementValidationResult}

Валидирует все элементы контейнера для указанной стадии.
"""
function validate_container_by_stage(container::ModelElementContainer,
                                    stage::DetailedLifecycleStage
                                    )::Vector{ElementValidationResult}
    results = ElementValidationResult[]
    
    # Получение требований для стадии
    required_lod = get_minimum_lod(stage)
    required_loi = get_required_loi_for_stage(stage)
    
    # Получение элементов для стадии
    element_ids = get(container.by_stage, stage, UUID[])
    
    for elem_id in element_ids
        element = get(container.elements, elem_id, nothing)
        if element !== nothing
            result = validate_element(element, required_lod, required_loi)
            push!(results, result)
        end
    end
    
    return results
end

"""
    get_required_loi_for_stage(stage::DetailedLifecycleStage)::LevelOfInformation

Возвращает требуемый уровень LOI для стадии.
"""
function get_required_loi_for_stage(stage::DetailedLifecycleStage)::LevelOfInformation
    if stage in [Stage_PreProjectPlanning, Stage_PreProjectAnalysis]
        return LOI_A
    elseif stage in [Stage_PreProjectConcept, Stage_DesignAssignment]
        return LOI_B
    elseif stage in [Stage_DesignPreliminary, Stage_DesignBasic]
        return LOI_C
    elseif stage in [Stage_DesignDetailed, Stage_DesignExpertise]
        return LOI_D
    elseif stage in [Stage_ConstructionPrep, Stage_ConstructionMain]
        return LOI_E
    elseif stage in [Stage_ConstructionSpecial, Stage_ConstructionCommissioning]
        return LOI_F
    else
        return LOI_G  # Эксплуатация и далее
    end
end

# ============================================================================
# FUNCTIONS: Поиск и фильтрация
# ============================================================================

"""
    find_elements_by_type(container::ModelElementContainer,
                          element_type::ModelElementType)::Vector{ModelElement}

Находит элементы по типу.
"""
function find_elements_by_type(container::ModelElementContainer,
                              element_type::ModelElementType)::Vector{ModelElement}
    element_ids = get(container.by_type, element_type, UUID[])
    return [container.elements[id] for id in element_ids if haskey(container.elements, id)]
end

"""
    find_elements_by_classification(container::ModelElementContainer,
                                    classification::String)::Vector{ModelElement}

Находит элементы по классификационному коду.
"""
function find_elements_by_classification(container::ModelElementContainer,
                                        classification::String)::Vector{ModelElement}
    element_ids = get(container.by_classification, classification, UUID[])
    return [container.elements[id] for id in element_ids if haskey(container.elements, id)]
end

"""
    get_element_tree(container::ModelElementContainer, 
                     root_id::UUID)::Vector{NamedTuple}

Возвращает дерево элементов начиная от корня.
"""
function get_element_tree(container::ModelElementContainer, 
                         root_id::UUID)::Vector{NamedTuple{(:id, :name, :depth), Tuple{UUID, String, Int}}}
    tree = NamedTuple{(:id, :name, :depth), Tuple{UUID, String, Int}}[]
    
    function traverse(id::UUID, depth::Int)
        element = get(container.elements, id, nothing)
        if element !== nothing
            push!(tree, (id = id, name = element.name, depth = depth))
            for child_id in element.children
                traverse(child_id, depth + 1)
            end
        end
    end
    
    traverse(root_id, 0)
    return tree
end

# ============================================================================
# FUNCTIONS: Статистика и отчеты
# ============================================================================

"""
    get_element_statistics(container::ModelElementContainer)::NamedTuple

Возвращает статистику по элементам контейнера.
"""
function get_element_statistics(container::ModelElementContainer)::NamedTuple{
    (:total_count, :by_type, :by_status, :by_lod, :with_geometry),
    Tuple{Int, Dict{Symbol, Int}, Dict{Symbol, Int}, Dict{Symbol, Int}, Int}
}
    total = length(container.elements)
    
    by_type = Dict{Symbol, Int}()
    for (elem_type, ids) in container.by_type
        key = Symbol(string(elem_type))
        by_type[key] = length(ids)
    end
    
    by_status = Dict{Symbol, Int}()
    for element in values(container.elements)
        key = Symbol(string(element.status))
        by_status[key] = get(by_status, key, 0) + 1
    end
    
    by_lod = Dict{Symbol, Int}()
    for element in values(container.elements)
        key = Symbol(string(element.lod))
        by_lod[key] = get(by_lod, key, 0) + 1
    end
    
    with_geometry = count(e -> e.geometry !== nothing, values(container.elements))
    
    return (
        total_count = total,
        by_type = by_type,
        by_status = by_status,
        by_lod = by_lod,
        with_geometry = with_geometry
    )
end

"""
    export_element_report(container::ModelElementContainer)::String

Формирует текстовый отчет по элементам контейнера.
"""
function export_element_report(container::ModelElementContainer)::String
    stats = get_element_statistics(container)
    
    report = """
    # Отчет по элементам информационной модели
    ## Контейнер: $(container.name)
    
    ### Общая статистика
    - Всего элементов: $(stats.total_count)
    - Элементов с геометрией: $(stats.with_geometry)
    
    ### По типам элементов
    """
    
    for (elem_type, count) in stats.by_type
        report *= "\n- $elem_type: $count"
    end
    
    report *= "\n\n### По статусам\n"
    for (status, count) in stats.by_status
        report *= "\n- $status: $count"
    end
    
    report *= "\n\n### По уровням LOD\n"
    for (lod, count) in stats.by_lod
        report *= "\n- $lod: $count"
    end
    
    return report
end

export ModelElement, ModelElementContainer, ElementValidationResult
export add_element!, add_child_element!, add_parameter!, set_geometry!
export update_element_status!, add_related_element!
export add_change_record!, get_change_history
export validate_element, validate_container_by_stage
export get_required_loi_for_stage
export find_elements_by_type, find_elements_by_classification
export get_element_tree, get_element_statistics, export_element_report

end # module ModelElementManager
