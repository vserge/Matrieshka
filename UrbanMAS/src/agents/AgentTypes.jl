"""
    AgentTypes

Defines core agent type hierarchies and enumerations for the UrbanMAS system.

This module establishes the foundational types for all agents in the simulation,
including government levels, company types, specializations, and other classifications
required for modeling Russian construction industry participants.
"""
module AgentTypes

using UUIDs
using Dates

# Government hierarchy levels (Уровень 0 по ОТСУ)
@enum GovernmentLevel begin
    Federal      # Федеральный уровень (Минстрой, Ростехнадзор)
    Regional     # Региональный уровень (области, края, республики)
    Municipal    # Муниципальный уровень (города, районы)
end

# Company types for developers and contractors
@enum CompanyType begin
    StateOwned       # Государственная компания
    PrivateCompany   # Частная компания
    PublicCompany    # Публичная компания (АО)
    LLC              # Общество с ограниченной ответственностью
    Corporation      # Корпорация/Холдинг
    IndividualEntrepreneur  # Индивидуальный предприниматель
end

# Contractor specializations
@enum Specialization begin
    GeneralConstruction    # Общестроительные работы
    Foundation             # Фундаментные работы
    Concrete               # Бетонные работы
    MetalStructures        # Металлоконструкции
    Electrical             # Электромонтажные работы
    Plumbing               # Сантехнические работы
    HVAC                   # Отопление, вентиляция, кондиционирование
    Finishing              # Отделочные работы
    RoadConstruction       # Дорожное строительство
    Infrastructure         # Инфраструктурные работы
    Industrial             # Промышленное строительство
    Residential            # Жилищное строительство
end

# Product categories for suppliers
@enum ProductCategory begin
    BuildingMaterials      # Строительные материалы
    ConcreteProducts       # ЖБИ изделия
    MetalProducts          # Металлопрокат
    Equipment              # Оборудование
    Machinery              # Техника и механизмы
    EngineeringSystems     # Инженерные системы
    FinishingMaterials     # Отделочные материалы
    Utilities              # Коммунальные ресурсы
end

# Document types (Градостроительный кодекс)
@enum DocumentType begin
    GPZU                   # Градостроительный план земельного участка
    ProjectDocumentation   # Проектная документация
    ConstructionPermit     # Разрешение на строительство
    CommissioningPermit    # Разрешение на ввод в эксплуатацию
    ExpertConclusion       # Заключение экспертизы
    LandDocument           # Правоустанавливающий документ на землю
    TechnicalPlan          # Технический план
    ActOfAcceptance        # Акт приема-передачи
end

# Document status
@enum DocumentStatus begin
    Draft                  # В разработке
    Submitted              # Подан на рассмотрение
    UnderReview            # На рассмотрении
    Approved               # Согласован
    Rejected               # Отклонен
    Expired                # Истек срок действия
    Cancelled              # Аннулирован
end

# Procurement types (44-ФЗ, 223-ФЗ)
@enum ProcurementType begin
    OpenTender             # Открытый конкурс
    ElectronicAuction      # Электронный аукцион
    RequestQuotations      # Запрос котировок
    SingleSource           # Закупка у единственного поставщика
    CompetitiveDialogue    # Конкурс с ограниченным участием
    TwoStageTender         # Двухэтапный конкурс
end

# Risk categories
@enum RiskCategory begin
    Regulatory             # Регуляторные риски
    Financial              # Финансовые риски
    Technical              # Технические риски
    Schedule               # Риски сроков
    ForceMajeure           # Форс-мажор
    Market                 # Рыночные риски
    Environmental          # Экологические риски
    Social                 # Социальные риски
end

# Lifecycle stages (Федеральный закон о капитальных вложениях)
@enum LifecycleStage begin
    PreInvestment          # Предынвестиционная фаза
    Investment             # Инвестиционная фаза
    Design                 # Проектирование
    Construction           # Строительство
    Commissioning          # Ввод в эксплуатацию
    Operation              # Эксплуатация
    Modernization          # Модернизация/Реконструкция
    Decommissioning        # Вывод из эксплуатации
end

# Compliance status
@enum ComplianceStatus begin
    Compliant              # Соответствует требованиям
    MinorViolations        # Незначительные нарушения
    MajorViolations        # Значительные нарушения
    Suspended              # Приостановлена деятельность
    Blacklisted            # В реестре недобросовестных поставщиков
end

# Project status
@enum ProjectStatus begin
    Planning               # Планирование
    Approval               # Согласование
    Active                 # Активная фаза
    OnHold                 # Приостановлен
    Completed              # Завершен
    Cancelled              # Отменен
    Archived               # Архивирован
end

# Abstract base type for all agents
abstract type AbstractAgent end

# Base structure for monetary values
struct Money
    amount::Float64
    currency::Symbol
    
    function Money(amount::Real, currency::Symbol=:RUB)
        new(Float64(amount), currency)
    end
end

Base.:+(a::Money, b::Money) = Money(a.amount + b.amount, a.currency)
Base.:-(a::Money, b::Money) = Money(a.amount - b.amount, a.currency)
Base.:*(a::Money, b::Real) = Money(a.amount * b, a.currency)
Base.:/(a::Money, b::Real) = Money(a.amount / b, a.currency)
Base.isless(a::Money, b::Money) = a.amount < b.amount

# Time period representation
struct TimePeriod
    value::Float64
    unit::Symbol  # :day, :month, :year
    
    function TimePeriod(value::Real, unit::Symbol=:day)
        @assert unit in [:minute, :hour, :day, :week, :month, :year]
        new(Float64(value), unit)
    end
end

# Budget structure
struct Budget
    total::Money
    allocated::Money
    spent::Money
    reserved::Money
    fiscal_year::Int
    
    function Budget(total::Money; allocated::Money=Money(0), 
                   spent::Money=Money(0), reserved::Money=Money(0),
                   fiscal_year::Int=Dates.year(Dates.now()))
        new(total, allocated, spent, reserved, fiscal_year)
    end
end

# License/Certification structure
struct License
    number::String
    type::Symbol
    issue_date::Date
    expiry_date::Date
    issuing_authority::String
    scope::Vector{Symbol}
    status::Symbol  # :active, :suspended, :expired, :revoked
end

# SRO (Саморегулируемая организация) membership
struct SROMembership
    organization::String
    member_number::String
    membership_date::Date
    contribution_paid::Money
    compensation_fund::Money
    permitted_works::Vector{Specialization}
    status::Symbol
end

export GovernmentLevel, CompanyType, Specialization, ProductCategory
export DocumentType, DocumentStatus, ProcurementType, RiskCategory
export LifecycleStage, ComplianceStatus, ProjectStatus
export AbstractAgent, Money, TimePeriod, Budget, License, SROMembership

end # module AgentTypes
