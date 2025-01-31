import Foundation

/// Provides the format to convert a [GraphQL Input Object](https://spec.graphql.org/draft/#sec-Input-Objects)
/// into Swift code.
struct InputObjectTemplate: TemplateRenderer {
  /// IR representation of source [GraphQL Input Object](https://spec.graphql.org/draft/#sec-Input-Objects).
  let graphqlInputObject: GraphQLInputObjectType

  let config: ApolloCodegen.ConfigurationContext

  let target: TemplateTarget = .schemaFile(type: .inputObject)

  var template: TemplateString {
    let (validFields, deprecatedFields) = filterFields(graphqlInputObject.fields)
    let memberAccessControl = accessControlModifier(for: .member)

    return TemplateString(
    """
    \(documentation: graphqlInputObject.documentation, config: config)
    \(accessControlModifier(for: .parent))\
    struct \(graphqlInputObject.name.firstUppercased): InputObject {
      \(memberAccessControl)private(set) var __data: InputDict
    
      \(memberAccessControl)init(_ data: InputDict) {
        __data = data
      }

      \(if: !deprecatedFields.isEmpty && !validFields.isEmpty && shouldIncludeDeprecatedWarnings, """
      \(memberAccessControl)init(
        \(InitializerParametersTemplate(validFields))
      ) {
        __data = InputDict([
          \(InputDictInitializerTemplate(validFields))
        ])
      }

      """
      )
      \(if: !deprecatedFields.isEmpty && shouldIncludeDeprecatedWarnings, """
      @available(*, deprecated, message: "\(deprecatedMessage(for: deprecatedFields))")
      """)
      \(memberAccessControl)init(
        \(InitializerParametersTemplate(graphqlInputObject.fields))
      ) {
        __data = InputDict([
          \(InputDictInitializerTemplate(graphqlInputObject.fields))
        ])
      }

      \(graphqlInputObject.fields.map({ "\(FieldPropertyTemplate($1))" }), separator: "\n\n")
    }

    """
    )
  }

  private var shouldIncludeDeprecatedWarnings: Bool {
    config.options.warningsOnDeprecatedUsage == .include
  }

  private func filterFields(
    _ fields: GraphQLInputFieldDictionary
  ) -> (valid: GraphQLInputFieldDictionary, deprecated: GraphQLInputFieldDictionary) {
    var valid: GraphQLInputFieldDictionary = [:]
    var deprecated: GraphQLInputFieldDictionary = [:]

    for (key, value) in fields {
      if let _ = value.deprecationReason {
        deprecated[key] = value
      } else {
        valid[key] = value
      }
    }

    return (valid: valid, deprecated: deprecated)
  }

  private func deprecatedMessage(for fields: GraphQLInputFieldDictionary) -> String {
    guard !fields.isEmpty else { return "" }

    let names: String = fields.values.map({ $0.name }).joined(separator: ", ")

    if fields.count > 1 {
      return "Arguments '\(names)' are deprecated."
    } else {
      return "Argument '\(names)' is deprecated."
    }
  }

  private func InitializerParametersTemplate(
    _ fields: GraphQLInputFieldDictionary
  ) -> TemplateString {
    TemplateString("""
    \(fields.map({
      "\($1.name.asFieldPropertyName): \($1.renderInputValueType(includeDefault: true, config: config.config))"
    }), separator: ",\n")
    """)
  }

  private func InputDictInitializerTemplate(
    _ fields: GraphQLInputFieldDictionary
  ) -> TemplateString {
    TemplateString("""
    \(fields.map({ "\"\($1.name)\": \($1.name.asFieldPropertyName)" }), separator: ",\n")
    """)
  }

  private func FieldPropertyTemplate(_ field: GraphQLInputField) -> TemplateString {
    """
    \(documentation: field.documentation, config: config)
    \(deprecationReason: field.deprecationReason, config: config)
    \(accessControlModifier(for: .member))\
    var \(field.name.asFieldPropertyName): \(field.renderInputValueType(config: config.config)) {
      get { __data["\(field.name)"] }
      set { __data["\(field.name)"] = newValue }
    }
    """
  }
}
