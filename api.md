{
  "x-generator": "NSwag v14.0.0.0 (NJsonSchema v11.0.0.0 (Newtonsoft.Json v13.0.0.0))",
  "swagger": "2.0",
  "info": {
    "title": "Property Manager Api",
    "description": "Property Manager Api",
    "termsOfService": "",
    "contact": {
      "name": "Stephen Kaguri",
      "url": "https://estatic.live",
      "email": "stephen.kaguri@estatic.live"
    },
    "license": {
      "name": "Use Under Estatic Api Rules And Regulations",
      "url": "https://estatic.live"
    },
    "version": "v1"
  },
  "host": "property-manager-api.transfa.org",
  "schemes": [
    "https"
  ],
  "produces": [
    "text/plain",
    "application/json",
    "text/json"
  ],
  "paths": {
    "/v1/api/auth/register": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_Register",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "user",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/UserRegistrationDto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/RegistrationResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/RegistrationResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/login": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_Login",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "user",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/UserLoginRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/RegistrationResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/RegistrationResponse"
            }
          },
          "401": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/enable/two/factor": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_EnableTwoFactor",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          },
          "404": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/verify/two/factor": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_VerifyTwoFactor",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/VerifyTwoFactorRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/AuthResult"
            }
          },
          "404": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/refresh/token": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_RefreshToken",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "tokenRequest",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/TokenRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/RegistrationResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/RegistrationResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/confirm/phonenumber": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_ConfirmPhoneNumber",
        "parameters": [
          {
            "type": "string",
            "name": "email",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "token",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/confirm/email": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_ConfirmEmail",
        "parameters": [
          {
            "type": "string",
            "name": "email",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "token",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/forgot/password": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_ForgotPassword",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "forgotPasswordRequest",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/ForgotPasswordRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/reset/password": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_ResetPassword",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "resetPasswordRequest",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/ResetPasswordRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/change/password": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_ChangePassword",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/ChangePasswordRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          },
          "404": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/update/profile/picture": {
      "post": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_UpdateProfilePicture",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "formFile",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/UpdateProfilePhoto"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/GenericResponseModel"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/GenericResponseModel"
            }
          },
          "404": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/GenericResponseModel"
            }
          }
        }
      }
    },
    "/v1/api/auth/get/users": {
      "get": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_GetUsers",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/MallUsers"
              }
            }
          }
        }
      }
    },
    "/v1/api/auth/update/user": {
      "put": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_UpdateUser",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "user",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/MallUsers"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "404": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/custom/update/user": {
      "put": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_UpdateCustomUser",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "user",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/UpdateUserRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "404": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/enable/disable/user": {
      "put": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_EnableAdmins",
        "parameters": [
          {
            "type": "string",
            "name": "id",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "404": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/get/account": {
      "get": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_GetMyAccount",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/MallUsers"
            }
          },
          "401": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/user/mobile/update": {
      "put": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_UpdateUserName",
        "parameters": [
          {
            "type": "string",
            "name": "userId",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "emailAddress",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "fullName",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "404": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/auth/delete/{id}": {
      "delete": {
        "tags": [
          "Auth"
        ],
        "operationId": "Auth_DeleteUser",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "404": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/book/unit": {
      "post": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_bookUnit",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreateBookingRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/all/bookings": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getAllBookings",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Invoice"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/invoices/{tenantId}": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getInvoices",
        "parameters": [
          {
            "type": "integer",
            "name": "tenantId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Invoice"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/invoices/unit/{unitId}": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getUnitInvoices",
        "parameters": [
          {
            "type": "integer",
            "name": "unitId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Invoice"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/invoices/block/{blockId}": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getBlockInvoices",
        "parameters": [
          {
            "type": "integer",
            "name": "blockId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Invoice"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/invoices/property/{propertyId}": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getPropertyInvoices",
        "parameters": [
          {
            "type": "integer",
            "name": "propertyId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Invoice"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/create/payment/request": {
      "post": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_makePaymentRequest",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreateMpesaPaymentRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Invoice"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/defer/invoice": {
      "post": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_deferInvoice",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/DeferInvoiceRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Invoice"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/settle/invoice": {
      "post": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_SettleInvoice",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/SettleInvoiceRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/mpesa/payments": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getMpesaMpayments",
        "parameters": [
          {
            "type": "integer",
            "name": "propertyId",
            "in": "query",
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/MpesaTransactions"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/mpesa/payment/by/trans/id": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getMpesaMpaymentById",
        "parameters": [
          {
            "type": "string",
            "name": "transId",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/MpesaTransactions"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/mpesa/payment/by/unit/{unitId}": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getMpesaPaymentByUnitId",
        "parameters": [
          {
            "type": "integer",
            "name": "unitId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/MpesaTransactions"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/mpesa/payment/by/block/{blockId}": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getMpesaPaymentByBlockId",
        "parameters": [
          {
            "type": "integer",
            "name": "blockId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/MpesaTransactions"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/mpesa/payment/by/property/{propertyId}": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getMpesaPaymentByPropertyId",
        "parameters": [
          {
            "type": "integer",
            "name": "propertyId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/MpesaTransactions"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/create/manual/payment": {
      "post": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_CreateManualPayment",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreateBankPaymentRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/bank/payments": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getBankPayments",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/BankPayments"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/delete/bank/payment/{Id}": {
      "delete": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_deleteBankPayments",
        "parameters": [
          {
            "type": "integer",
            "name": "Id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/SuccessResponse"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/update/bank/payment": {
      "put": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_updateBankPayments",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "bankPayment",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/BankPayments"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/SuccessResponse"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/update/mpesa/acc/no": {
      "put": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_updateMpesaPaymentsAcc",
        "parameters": [
          {
            "type": "string",
            "name": "accountNumber",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "integer",
            "name": "Id",
            "in": "query",
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/SuccessResponse"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/payments/get/owner/report": {
      "get": {
        "tags": [
          "Payments"
        ],
        "operationId": "Payments_getOwnerReport",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/MpesaTransactions"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/get/all/properties": {
      "get": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_getAllProperties",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Property"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/get/property/{id}": {
      "get": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_getProperty",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/Property"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/create/property": {
      "post": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_CreateProperty",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreatePropertyRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/delete/property/{id}": {
      "delete": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_deleteProperty",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/restore/property/{id}": {
      "put": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_restoreProperty",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/update/property/{id}": {
      "put": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_updateProperty",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          },
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreatePropertyRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/get/all/blocks/{propertyId}": {
      "get": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_getAllBlocksByProperty",
        "parameters": [
          {
            "type": "integer",
            "name": "propertyId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Property"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/get/block/{id}": {
      "get": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_getBlock",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/Property"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/create/block": {
      "post": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_createBlock",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreatePropertyBlock"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/update/block/{id}": {
      "put": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_updateBlock",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          },
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreatePropertyBlock"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/delete/block/{id}": {
      "delete": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_deleteBlock",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/create/unit": {
      "post": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_createUnit",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreateUnitRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/get/all/units/in/property{propertyId}": {
      "get": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_getAllUnitsInProperty",
        "parameters": [
          {
            "type": "integer",
            "name": "propertyId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Property"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/get/all/units/in/block{blockId}": {
      "get": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_getAllUnitsInBlock",
        "parameters": [
          {
            "type": "integer",
            "name": "blockId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Property"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/get/unit/{id}": {
      "get": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_getUnit",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/Property"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/update/unit/{id}": {
      "put": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_updateUnit",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          },
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreateUnitRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/delete/unit/{id}": {
      "delete": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_deleteUnit",
        "parameters": [
          {
            "type": "integer",
            "name": "id",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/available/units/to/book": {
      "get": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_GetAvailableUnitsToBook",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/get/all/tenants": {
      "get": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_GetTenants",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Tenant"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/create/tenant": {
      "post": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_CreateTenant",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreateTenantRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Tenant"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/assign/unit/to/tenant": {
      "post": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_AssignUnitToTenant",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/AssignTenantToUnitRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/terminate/lease/{leaseId}": {
      "put": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_terminateLease",
        "parameters": [
          {
            "type": "integer",
            "name": "leaseId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/unassign/unit/from/tenant": {
      "post": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_UnassignUnitFromTenant",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/UnassignUnitRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/delete/tenant/{tenantId}": {
      "delete": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_DeleteTenant",
        "parameters": [
          {
            "type": "integer",
            "name": "tenantId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/update/tenant/{tenantId}": {
      "put": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_UpdateTenant",
        "consumes": [
          "application/json",
          "text/json",
          "application/*+json"
        ],
        "parameters": [
          {
            "type": "integer",
            "name": "tenantId",
            "in": "path",
            "required": true,
            "format": "int64",
            "x-nullable": false
          },
          {
            "name": "request",
            "in": "body",
            "required": true,
            "schema": {
              "$ref": "#/definitions/CreateTenantRequest"
            },
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/properties/get/lease/aggreements": {
      "get": {
        "tags": [
          "Properties"
        ],
        "operationId": "Properties_GetLeaseAgreements",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/roles/get/all/roles": {
      "get": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_GetAllRoles",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/IdentityRole"
              }
            }
          }
        }
      }
    },
    "/v1/api/roles/create/role": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_CreateRole",
        "parameters": [
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/roles/get/all/users": {
      "get": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_GetAllUsers",
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/UserWithRolesResponse"
              }
            }
          }
        }
      }
    },
    "/v1/api/roles/add/user/to/role": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_AddUserToRole",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/roles/get/user/roles": {
      "get": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_GetUserRoles",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/IdentityRole"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/roles/remove/user/from/role": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_RemoveUserFromRole",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/roles/get/all/claims": {
      "get": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_GetAllClaims",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Claim"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/roles/add/claims/to/user": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_AddClaimsToUser",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "claimName",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "claimValue",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/roles/remove/claim/from/user": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_RemoveClaimFromUser",
        "parameters": [
          {
            "type": "string",
            "name": "phoneNumber",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "claimName",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "claimValue",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/roles/add/claim/to/role": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_AddClaimToRole",
        "parameters": [
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "claimType",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "claimValue",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/roles/get/claims/for/role": {
      "get": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_GetClaimsForRole",
        "parameters": [
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "type": "array",
              "items": {
                "$ref": "#/definitions/Claim"
              }
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    },
    "/v1/api/roles/remove/claim/from/role": {
      "post": {
        "tags": [
          "Roles"
        ],
        "operationId": "Roles_RemoveClaimFromRole",
        "parameters": [
          {
            "type": "string",
            "name": "roleName",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "claimType",
            "in": "query",
            "x-nullable": false
          },
          {
            "type": "string",
            "name": "claimValue",
            "in": "query",
            "x-nullable": false
          }
        ],
        "responses": {
          "200": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/SuccessResponse"
            }
          },
          "400": {
            "x-nullable": false,
            "description": "",
            "schema": {
              "$ref": "#/definitions/ErrorResponse"
            }
          }
        }
      }
    }
  },
  "definitions": {
    "RegistrationResponse": {
      "allOf": [
        {
          "$ref": "#/definitions/AuthResult"
        },
        {
          "type": "object"
        }
      ]
    },
    "AuthResult": {
      "type": "object",
      "required": [
        "token",
        "refreshToken",
        "success",
        "userId",
        "email",
        "phone",
        "idNumber",
        "userName",
        "errors",
        "user"
      ],
      "properties": {
        "token": {
          "type": "string"
        },
        "refreshToken": {
          "type": "string"
        },
        "success": {
          "type": "boolean"
        },
        "userId": {
          "type": "string"
        },
        "email": {
          "type": "string"
        },
        "phone": {
          "type": "string"
        },
        "idNumber": {
          "type": "string"
        },
        "userName": {
          "type": "string"
        },
        "errors": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "user": {
          "$ref": "#/definitions/MallUsers"
        }
      }
    },
    "MallUsers": {
      "type": "object",
      "required": [
        "id",
        "userId",
        "fullName",
        "phoneNumber",
        "emailAddress",
        "userOtp",
        "otpCreatedAt",
        "userRole",
        "profileImage",
        "privacyPolicyStatus",
        "userActive",
        "isDeleted",
        "createdBy",
        "createdByName",
        "updatedBy",
        "updatedByName",
        "deletedBy",
        "deletedByName",
        "firebaseToken",
        "adminPhoneNumber",
        "adminUserId",
        "propertyIds",
        "isTenant",
        "isOwner",
        "lastLogin",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "userId": {
          "type": "string"
        },
        "fullName": {
          "type": "string"
        },
        "phoneNumber": {
          "type": "string"
        },
        "emailAddress": {
          "type": "string"
        },
        "userOtp": {
          "type": "string"
        },
        "otpCreatedAt": {
          "type": "string",
          "format": "date-time"
        },
        "userRole": {
          "type": "string"
        },
        "profileImage": {
          "type": "string"
        },
        "privacyPolicyStatus": {
          "type": "boolean"
        },
        "userActive": {
          "type": "boolean"
        },
        "isDeleted": {
          "type": "boolean"
        },
        "createdBy": {
          "type": "string"
        },
        "createdByName": {
          "type": "string"
        },
        "updatedBy": {
          "type": "string"
        },
        "updatedByName": {
          "type": "string"
        },
        "deletedBy": {
          "type": "string"
        },
        "deletedByName": {
          "type": "string"
        },
        "firebaseToken": {
          "type": "string"
        },
        "adminPhoneNumber": {
          "type": "string"
        },
        "adminUserId": {
          "type": "string"
        },
        "propertyIds": {
          "type": "string"
        },
        "isTenant": {
          "type": "boolean"
        },
        "isOwner": {
          "type": "boolean"
        },
        "lastLogin": {
          "type": "string",
          "format": "date-time"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "UserRegistrationDto": {
      "type": "object",
      "required": [
        "fullName",
        "phoneNumber",
        "emailAddress",
        "userRole",
        "password",
        "userFirebaseToken",
        "adminPhoneNumber"
      ],
      "properties": {
        "fullName": {
          "type": "string",
          "minLength": 1
        },
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "emailAddress": {
          "type": "string",
          "minLength": 1
        },
        "userRole": {
          "type": "string",
          "minLength": 1
        },
        "password": {
          "type": "string",
          "minLength": 1
        },
        "userFirebaseToken": {
          "type": "string"
        },
        "adminPhoneNumber": {
          "type": "string"
        }
      }
    },
    "ErrorResponse": {
      "type": "object",
      "required": [
        "message"
      ],
      "properties": {
        "message": {
          "type": "string"
        }
      }
    },
    "UserLoginRequest": {
      "type": "object",
      "required": [
        "phoneNumber",
        "password",
        "firebaseToken",
        "deviceModel",
        "userAgent",
        "location",
        "ipAddress"
      ],
      "properties": {
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "password": {
          "type": "string",
          "minLength": 1
        },
        "firebaseToken": {
          "type": "string"
        },
        "deviceModel": {
          "type": "string"
        },
        "userAgent": {
          "type": "string"
        },
        "location": {
          "type": "string"
        },
        "ipAddress": {
          "type": "string"
        }
      }
    },
    "SuccessResponse": {
      "type": "object",
      "required": [
        "message",
        "success"
      ],
      "properties": {
        "message": {
          "type": "string"
        },
        "success": {
          "type": "boolean"
        }
      }
    },
    "VerifyTwoFactorRequest": {
      "type": "object",
      "required": [
        "code",
        "email"
      ],
      "properties": {
        "code": {
          "type": "string",
          "minLength": 1
        },
        "email": {
          "type": "string"
        }
      }
    },
    "TokenRequest": {
      "type": "object",
      "required": [
        "token",
        "refreshToken"
      ],
      "properties": {
        "token": {
          "type": "string",
          "minLength": 1
        },
        "refreshToken": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "ForgotPasswordRequest": {
      "type": "object",
      "required": [
        "phoneNumber"
      ],
      "properties": {
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "ResetPasswordRequest": {
      "type": "object",
      "required": [
        "phoneNumber",
        "newPassword",
        "resetToken"
      ],
      "properties": {
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "newPassword": {
          "type": "string",
          "minLength": 1
        },
        "resetToken": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "ChangePasswordRequest": {
      "type": "object",
      "required": [
        "phoneNumber",
        "currentPassword",
        "newPassword"
      ],
      "properties": {
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "currentPassword": {
          "type": "string",
          "minLength": 1
        },
        "newPassword": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "GenericResponseModel": {
      "type": "object",
      "required": [
        "message",
        "statusCode",
        "success"
      ],
      "properties": {
        "message": {
          "type": "string"
        },
        "statusCode": {
          "type": "string"
        },
        "success": {
          "type": "boolean"
        }
      }
    },
    "UpdateProfilePhoto": {
      "type": "object",
      "required": [
        "image"
      ],
      "properties": {
        "image": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "UpdateUserRequest": {
      "type": "object",
      "required": [
        "userId",
        "fullName",
        "emailAddress",
        "phoneNumber",
        "profileImage"
      ],
      "properties": {
        "userId": {
          "type": "string",
          "minLength": 1
        },
        "fullName": {
          "type": "string",
          "minLength": 1
        },
        "emailAddress": {
          "type": "string",
          "minLength": 1
        },
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "profileImage": {
          "type": "string"
        }
      }
    },
    "CreateBookingRequest": {
      "type": "object",
      "required": [
        "propertyId",
        "fullName",
        "phoneNumber",
        "email",
        "companyName",
        "businessType",
        "description"
      ],
      "properties": {
        "propertyId": {
          "type": "integer",
          "format": "int64"
        },
        "fullName": {
          "type": "string",
          "minLength": 1
        },
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "email": {
          "type": "string"
        },
        "companyName": {
          "type": "string",
          "minLength": 1
        },
        "businessType": {
          "type": "string",
          "minLength": 1
        },
        "description": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "Invoice": {
      "type": "object",
      "required": [
        "id",
        "propertyId",
        "blockId",
        "unitId",
        "tenantId",
        "isDeferred",
        "type",
        "invoiceStatus",
        "isPaid",
        "paymentReceipt",
        "settledAmount",
        "invoiceDate",
        "dueDate",
        "settledOn",
        "cancellationReason",
        "subtotal",
        "taxAmount",
        "discountAmount",
        "totalAmount",
        "paidAmount",
        "balanceDue",
        "currencyCode",
        "notes",
        "termsAndConditions",
        "createdByName",
        "createdByUserId",
        "updatedByName",
        "updatedByUserId",
        "createdAt",
        "updatedAt",
        "property",
        "unit",
        "tenant",
        "lease",
        "payments"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "propertyId": {
          "type": "integer",
          "format": "int64"
        },
        "blockId": {
          "type": "integer",
          "format": "int64"
        },
        "unitId": {
          "type": "integer",
          "format": "int64"
        },
        "tenantId": {
          "type": "integer",
          "format": "int64"
        },
        "leaseId": {
          "type": "integer",
          "format": "int64"
        },
        "bookingId": {
          "type": "integer",
          "format": "int64"
        },
        "isDeferred": {
          "type": "boolean"
        },
        "deferReason": {
          "type": "string"
        },
        "type": {
          "$ref": "#/definitions/InvoiceType"
        },
        "invoiceStatus": {
          "type": "string"
        },
        "isPaid": {
          "type": "boolean"
        },
        "paymentReceipt": {
          "type": "string"
        },
        "settledAmount": {
          "type": "number",
          "format": "decimal"
        },
        "invoiceDate": {
          "type": "string",
          "format": "date-time"
        },
        "dueDate": {
          "type": "string",
          "format": "date-time"
        },
        "paidDate": {
          "type": "string",
          "format": "date-time"
        },
        "cancelledDate": {
          "type": "string",
          "format": "date-time"
        },
        "settledOn": {
          "type": "string",
          "format": "date-time"
        },
        "cancellationReason": {
          "type": "string"
        },
        "subtotal": {
          "type": "number",
          "format": "decimal"
        },
        "taxAmount": {
          "type": "number",
          "format": "decimal"
        },
        "discountAmount": {
          "type": "number",
          "format": "decimal"
        },
        "totalAmount": {
          "type": "number",
          "format": "decimal"
        },
        "paidAmount": {
          "type": "number",
          "format": "decimal"
        },
        "balanceDue": {
          "type": "number",
          "format": "decimal"
        },
        "currencyCode": {
          "type": "string"
        },
        "notes": {
          "type": "string"
        },
        "termsAndConditions": {
          "type": "string"
        },
        "createdByName": {
          "type": "string"
        },
        "createdByUserId": {
          "type": "string"
        },
        "updatedByName": {
          "type": "string"
        },
        "updatedByUserId": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        },
        "property": {
          "$ref": "#/definitions/Property"
        },
        "unit": {
          "$ref": "#/definitions/PropertyUnit"
        },
        "tenant": {
          "$ref": "#/definitions/Tenant"
        },
        "lease": {
          "$ref": "#/definitions/Lease"
        },
        "payments": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/MpesaTransactions"
          }
        }
      }
    },
    "InvoiceType": {
      "type": "integer",
      "description": "",
      "x-enumNames": [
        "Rent",
        "Deposit",
        "BookingFee",
        "ServiceCharge",
        "Utility",
        "Maintenance",
        "Penalty",
        "Adjustment",
        "CreditNote",
        "DebitNote",
        "Other"
      ],
      "enum": [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10
      ]
    },
    "Property": {
      "type": "object",
      "required": [
        "id",
        "propertyName",
        "type",
        "status",
        "description",
        "city",
        "country",
        "phone",
        "email",
        "totalUnits",
        "leasableUnits",
        "isDeleted",
        "createdByName",
        "createdByUserId",
        "updatedByName",
        "updatedByUserId",
        "createdAt",
        "updatedAt",
        "blocks",
        "units"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "propertyName": {
          "type": "string"
        },
        "type": {
          "$ref": "#/definitions/PropertyType"
        },
        "status": {
          "$ref": "#/definitions/PropertyStatus"
        },
        "description": {
          "type": "string"
        },
        "city": {
          "type": "string"
        },
        "country": {
          "type": "string"
        },
        "latitude": {
          "type": "number",
          "format": "decimal"
        },
        "longitude": {
          "type": "number",
          "format": "decimal"
        },
        "phone": {
          "type": "string"
        },
        "email": {
          "type": "string"
        },
        "totalAreaSqFeet": {
          "type": "number",
          "format": "decimal"
        },
        "leasableAreaSqFeet": {
          "type": "number",
          "format": "decimal"
        },
        "totalUnits": {
          "type": "integer",
          "format": "int32"
        },
        "leasableUnits": {
          "type": "integer",
          "format": "int32"
        },
        "isDeleted": {
          "type": "boolean"
        },
        "createdByName": {
          "type": "string"
        },
        "createdByUserId": {
          "type": "string"
        },
        "updatedByName": {
          "type": "string"
        },
        "updatedByUserId": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        },
        "blocks": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/PropertyBlock"
          }
        },
        "units": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/PropertyUnit"
          }
        }
      }
    },
    "PropertyType": {
      "type": "integer",
      "description": "",
      "x-enumNames": [
        "Mall",
        "ShoppingCentre",
        "OfficeBuilding",
        "Warehouse",
        "BusinessCentre",
        "MixedUse",
        "CommercialBuilding"
      ],
      "enum": [
        0,
        1,
        2,
        3,
        4,
        5,
        6
      ]
    },
    "PropertyStatus": {
      "type": "integer",
      "description": "",
      "x-enumNames": [
        "Active",
        "Inactive",
        "UnderMaintenance",
        "Archived"
      ],
      "enum": [
        0,
        1,
        2,
        3
      ]
    },
    "PropertyBlock": {
      "type": "object",
      "required": [
        "id",
        "propertyId",
        "blockName",
        "description",
        "status",
        "numberOfFloors",
        "totalUnits",
        "leasableUnits",
        "isDeleted",
        "createdByName",
        "createdByUserId",
        "updatedByName",
        "updatedByUserId",
        "createdAt",
        "updatedAt",
        "property",
        "units"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "propertyId": {
          "type": "integer",
          "format": "int64"
        },
        "blockName": {
          "type": "string"
        },
        "description": {
          "type": "string"
        },
        "status": {
          "$ref": "#/definitions/BlockStatus"
        },
        "totalAreaSqFeet": {
          "type": "number",
          "format": "decimal"
        },
        "numberOfFloors": {
          "type": "integer",
          "format": "int32"
        },
        "totalUnits": {
          "type": "integer",
          "format": "int32"
        },
        "leasableUnits": {
          "type": "integer",
          "format": "int32"
        },
        "isDeleted": {
          "type": "boolean"
        },
        "createdByName": {
          "type": "string"
        },
        "createdByUserId": {
          "type": "string"
        },
        "updatedByName": {
          "type": "string"
        },
        "updatedByUserId": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        },
        "property": {
          "$ref": "#/definitions/Property"
        },
        "units": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/PropertyUnit"
          }
        }
      }
    },
    "BlockStatus": {
      "type": "integer",
      "description": "",
      "x-enumNames": [
        "Active",
        "Inactive",
        "UnderConstruction",
        "UnderMaintenance",
        "Archived"
      ],
      "enum": [
        0,
        1,
        2,
        3,
        4
      ]
    },
    "PropertyUnit": {
      "type": "object",
      "required": [
        "id",
        "propertyId",
        "blockId",
        "unitNumber",
        "type",
        "status",
        "description",
        "monthlyRent",
        "bookingFeeType",
        "depositAmount",
        "depositPercentage",
        "serviceChargeAmount",
        "depositMonths",
        "bookingFeePercentage",
        "gracePeriodDays",
        "isDeleted",
        "isAvailable",
        "createdByName",
        "createdByUserId",
        "updatedByName",
        "updatedByUserId",
        "availableUntill",
        "createdAt",
        "updatedAt",
        "property",
        "block",
        "currentTenant",
        "currentLease",
        "bookings",
        "leases"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "propertyId": {
          "type": "integer",
          "format": "int64"
        },
        "blockId": {
          "type": "integer",
          "format": "int64"
        },
        "unitNumber": {
          "type": "string"
        },
        "type": {
          "$ref": "#/definitions/UnitType"
        },
        "status": {
          "$ref": "#/definitions/UnitStatus"
        },
        "description": {
          "type": "string"
        },
        "areaSqFeet": {
          "type": "number",
          "format": "decimal"
        },
        "monthlyRent": {
          "type": "number",
          "format": "decimal"
        },
        "bookingFeeType": {
          "type": "string"
        },
        "depositAmount": {
          "type": "number",
          "format": "decimal"
        },
        "depositPercentage": {
          "type": "number",
          "format": "decimal"
        },
        "serviceChargeAmount": {
          "type": "number",
          "format": "decimal"
        },
        "depositMonths": {
          "type": "integer",
          "format": "int32"
        },
        "bookingFeePercentage": {
          "type": "number",
          "format": "decimal"
        },
        "gracePeriodDays": {
          "type": "integer",
          "format": "int32"
        },
        "wing": {
          "type": "string"
        },
        "section": {
          "type": "string"
        },
        "floorNumber": {
          "type": "integer",
          "format": "int32"
        },
        "availableFrom": {
          "type": "string",
          "format": "date-time"
        },
        "currentTenantId": {
          "type": "integer",
          "format": "int64"
        },
        "isDeleted": {
          "type": "boolean"
        },
        "isAvailable": {
          "type": "boolean"
        },
        "createdByName": {
          "type": "string"
        },
        "createdByUserId": {
          "type": "string"
        },
        "updatedByName": {
          "type": "string"
        },
        "updatedByUserId": {
          "type": "string"
        },
        "availableUntill": {
          "type": "string",
          "format": "date-time"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        },
        "property": {
          "$ref": "#/definitions/Property"
        },
        "block": {
          "$ref": "#/definitions/PropertyBlock"
        },
        "currentTenant": {
          "$ref": "#/definitions/Tenant"
        },
        "currentLease": {
          "$ref": "#/definitions/Lease"
        },
        "bookings": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Booking"
          }
        },
        "leases": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Lease"
          }
        }
      }
    },
    "UnitType": {
      "type": "integer",
      "description": "",
      "x-enumNames": [
        "Shop",
        "Kiosk",
        "Office",
        "Restaurant",
        "FoodCourt",
        "Supermarket",
        "Entertainment",
        "Storage",
        "ParkingSpace",
        "Billboard",
        "Other"
      ],
      "enum": [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10
      ]
    },
    "UnitStatus": {
      "type": "integer",
      "description": "",
      "x-enumNames": [
        "Available",
        "Booked",
        "Reserved",
        "Leased",
        "Blocked",
        "UnderMaintenance",
        "Inactive"
      ],
      "enum": [
        0,
        1,
        2,
        3,
        4,
        5,
        6
      ]
    },
    "Tenant": {
      "type": "object",
      "required": [
        "id",
        "userId",
        "fullName",
        "email",
        "phoneNumber",
        "idNumber",
        "businessName",
        "businessRegistrationNumber",
        "taxPin",
        "businessType",
        "emergencyContactName",
        "emergencyContactPhone",
        "emergencyContactEmail",
        "createdByName",
        "createdByUserId",
        "updatedByName",
        "updatedByUserId",
        "unitIds",
        "isDeleted",
        "status",
        "createdAt",
        "updatedAt",
        "leases",
        "units",
        "invoices",
        "payments"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "userId": {
          "type": "string"
        },
        "fullName": {
          "type": "string"
        },
        "email": {
          "type": "string"
        },
        "phoneNumber": {
          "type": "string"
        },
        "idNumber": {
          "type": "string"
        },
        "businessName": {
          "type": "string"
        },
        "businessRegistrationNumber": {
          "type": "string"
        },
        "taxPin": {
          "type": "string"
        },
        "businessType": {
          "type": "string"
        },
        "emergencyContactName": {
          "type": "string"
        },
        "emergencyContactPhone": {
          "type": "string"
        },
        "emergencyContactEmail": {
          "type": "string"
        },
        "createdByName": {
          "type": "string"
        },
        "createdByUserId": {
          "type": "string"
        },
        "updatedByName": {
          "type": "string"
        },
        "updatedByUserId": {
          "type": "string"
        },
        "unitIds": {
          "type": "string"
        },
        "isDeleted": {
          "type": "boolean"
        },
        "status": {
          "$ref": "#/definitions/TenantStatus"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        },
        "leases": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Lease"
          }
        },
        "units": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/PropertyUnit"
          }
        },
        "invoices": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Invoice"
          }
        },
        "payments": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/MpesaTransactions"
          }
        }
      }
    },
    "TenantStatus": {
      "type": "integer",
      "description": "",
      "x-enumNames": [
        "Active",
        "Inactive",
        "Blacklisted",
        "Suspended"
      ],
      "enum": [
        0,
        1,
        2,
        3
      ]
    },
    "Lease": {
      "type": "object",
      "required": [
        "id",
        "propertyId",
        "blockId",
        "unitId",
        "tenantId",
        "leaseAgreementUrls",
        "status",
        "startDate",
        "endDate",
        "monthlyRent",
        "depositAmount",
        "serviceChargePerMonth",
        "gracePeriodDays",
        "createdByName",
        "createdByUserId",
        "updatedByName",
        "updatedByUserId",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "propertyId": {
          "type": "integer",
          "format": "int64"
        },
        "blockId": {
          "type": "integer",
          "format": "int64"
        },
        "unitId": {
          "type": "integer",
          "format": "int64"
        },
        "tenantId": {
          "type": "integer",
          "format": "int64"
        },
        "leaseAgreementUrls": {
          "type": "string"
        },
        "status": {
          "type": "string"
        },
        "startDate": {
          "type": "string",
          "format": "date-time"
        },
        "endDate": {
          "type": "string",
          "format": "date-time"
        },
        "monthlyRent": {
          "type": "number",
          "format": "decimal"
        },
        "depositAmount": {
          "type": "number",
          "format": "decimal"
        },
        "serviceChargePerMonth": {
          "type": "number",
          "format": "decimal"
        },
        "gracePeriodDays": {
          "type": "integer",
          "format": "int32"
        },
        "termsAndConditions": {
          "type": "string"
        },
        "specialConditions": {
          "type": "string"
        },
        "createdByName": {
          "type": "string"
        },
        "createdByUserId": {
          "type": "string"
        },
        "updatedByName": {
          "type": "string"
        },
        "updatedByUserId": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "MpesaTransactions": {
      "type": "object",
      "required": [
        "id",
        "propertyId",
        "blockId",
        "unitId",
        "transactionType",
        "transID",
        "transTime",
        "transAmount",
        "businessShortCode",
        "billRefNumber",
        "orgAccountBalance",
        "thirdPartyTransID",
        "msisdn",
        "firstName",
        "processed",
        "is_reissued",
        "is_edited",
        "is_split",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "propertyId": {
          "type": "integer",
          "format": "int64"
        },
        "blockId": {
          "type": "integer",
          "format": "int64"
        },
        "unitId": {
          "type": "integer",
          "format": "int64"
        },
        "transactionType": {
          "type": "string"
        },
        "transID": {
          "type": "string"
        },
        "transTime": {
          "type": "string"
        },
        "transAmount": {
          "type": "string"
        },
        "businessShortCode": {
          "type": "string"
        },
        "billRefNumber": {
          "type": "string"
        },
        "invoiceNumber": {
          "type": "integer",
          "format": "int64"
        },
        "orgAccountBalance": {
          "type": "string"
        },
        "thirdPartyTransID": {
          "type": "string"
        },
        "msisdn": {
          "type": "string"
        },
        "firstName": {
          "type": "string"
        },
        "processed": {
          "type": "boolean"
        },
        "reissueId": {
          "type": "integer",
          "format": "int32"
        },
        "is_reissued": {
          "type": "boolean"
        },
        "is_edited": {
          "type": "boolean"
        },
        "extendedPaymentReceipt": {
          "type": "string"
        },
        "is_split": {
          "type": "boolean"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "Booking": {
      "type": "object",
      "required": [
        "id",
        "propertyId",
        "fullName",
        "phoneNumber",
        "email",
        "companyName",
        "businessType",
        "description",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "propertyId": {
          "type": "integer",
          "format": "int64"
        },
        "fullName": {
          "type": "string"
        },
        "phoneNumber": {
          "type": "string"
        },
        "email": {
          "type": "string"
        },
        "companyName": {
          "type": "string"
        },
        "businessType": {
          "type": "string"
        },
        "description": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "CreateMpesaPaymentRequest": {
      "type": "object",
      "required": [
        "invoiceId",
        "phoneNumber",
        "amount"
      ],
      "properties": {
        "invoiceId": {
          "type": "integer",
          "format": "int64"
        },
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "amount": {
          "type": "integer",
          "format": "int32"
        }
      }
    },
    "DeferInvoiceRequest": {
      "type": "object",
      "required": [
        "invoiceId",
        "deferReason"
      ],
      "properties": {
        "invoiceId": {
          "type": "integer",
          "format": "int64"
        },
        "deferReason": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "SettleInvoiceRequest": {
      "type": "object",
      "required": [
        "invoiceId"
      ],
      "properties": {
        "invoiceId": {
          "type": "integer",
          "format": "int64"
        }
      }
    },
    "CreateBankPaymentRequest": {
      "type": "object",
      "required": [
        "paymentDate",
        "amount",
        "paymentMethod",
        "paymentReference",
        "invoiceId",
        "tenantId",
        "propertyId",
        "blockId",
        "unitId",
        "purpose",
        "paidByName",
        "bankAccountNumber",
        "bankName",
        "branchName",
        "proofOfPaymentUrl"
      ],
      "properties": {
        "paymentDate": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        },
        "amount": {
          "type": "number",
          "format": "decimal"
        },
        "paymentMethod": {
          "type": "string",
          "minLength": 1
        },
        "paymentReference": {
          "type": "string",
          "minLength": 1
        },
        "invoiceId": {
          "type": "integer",
          "format": "int64"
        },
        "tenantId": {
          "type": "integer",
          "format": "int64"
        },
        "propertyId": {
          "type": "integer",
          "format": "int64"
        },
        "blockId": {
          "type": "integer",
          "format": "int64"
        },
        "unitId": {
          "type": "integer",
          "format": "int64"
        },
        "purpose": {
          "type": "string",
          "minLength": 1
        },
        "paidByName": {
          "type": "string",
          "minLength": 1
        },
        "bankAccountNumber": {
          "type": "string",
          "minLength": 1
        },
        "bankName": {
          "type": "string",
          "minLength": 1
        },
        "branchName": {
          "type": "string",
          "minLength": 1
        },
        "proofOfPaymentUrl": {
          "type": "string"
        }
      }
    },
    "BankPayments": {
      "type": "object",
      "required": [
        "id",
        "paymentDate",
        "amount",
        "paymentMethod",
        "paymentReference",
        "tenantId",
        "propertyId",
        "blockId",
        "unitId",
        "purpose",
        "paidBy",
        "bankAccountNumber",
        "bankName",
        "branchName",
        "status",
        "createdById",
        "createdByName",
        "isProcessed",
        "isSplit",
        "isDeleted",
        "isReissued",
        "deleteReason",
        "deletedById",
        "deletedByName",
        "deletedPaymentReference",
        "extendedPaymentReceipt",
        "proofOfPaymentUrl",
        "createdAt",
        "updatedAt"
      ],
      "properties": {
        "id": {
          "type": "integer",
          "format": "int64"
        },
        "paymentDate": {
          "type": "string",
          "format": "date-time"
        },
        "amount": {
          "type": "number",
          "format": "decimal"
        },
        "paymentMethod": {
          "type": "string"
        },
        "paymentReference": {
          "type": "string"
        },
        "invoiceId": {
          "type": "integer",
          "format": "int64"
        },
        "tenantId": {
          "type": "integer",
          "format": "int64"
        },
        "propertyId": {
          "type": "integer",
          "format": "int64"
        },
        "blockId": {
          "type": "integer",
          "format": "int64"
        },
        "unitId": {
          "type": "integer",
          "format": "int64"
        },
        "purpose": {
          "type": "string"
        },
        "paidBy": {
          "type": "string"
        },
        "bankAccountNumber": {
          "type": "string"
        },
        "bankName": {
          "type": "string"
        },
        "branchName": {
          "type": "string"
        },
        "status": {
          "type": "string"
        },
        "createdById": {
          "type": "string"
        },
        "createdByName": {
          "type": "string"
        },
        "isProcessed": {
          "type": "boolean"
        },
        "isSplit": {
          "type": "boolean"
        },
        "isDeleted": {
          "type": "boolean"
        },
        "isReissued": {
          "type": "boolean"
        },
        "deleteReason": {
          "type": "string"
        },
        "deletedById": {
          "type": "string"
        },
        "deletedByName": {
          "type": "string"
        },
        "deletedPaymentReference": {
          "type": "string"
        },
        "extendedPaymentReceipt": {
          "type": "string"
        },
        "proofOfPaymentUrl": {
          "type": "string"
        },
        "createdAt": {
          "type": "string",
          "format": "date-time"
        },
        "updatedAt": {
          "type": "string",
          "format": "date-time"
        }
      }
    },
    "CreatePropertyRequest": {
      "type": "object",
      "required": [
        "propertyName",
        "type",
        "status",
        "description",
        "city",
        "country",
        "phone",
        "email",
        "totalUnits",
        "leasableUnits"
      ],
      "properties": {
        "propertyName": {
          "type": "string",
          "minLength": 1
        },
        "type": {
          "$ref": "#/definitions/PropertyType"
        },
        "status": {
          "$ref": "#/definitions/PropertyStatus"
        },
        "description": {
          "type": "string",
          "minLength": 1
        },
        "city": {
          "type": "string",
          "minLength": 1
        },
        "country": {
          "type": "string",
          "minLength": 1
        },
        "latitude": {
          "type": "number",
          "format": "decimal"
        },
        "longitude": {
          "type": "number",
          "format": "decimal"
        },
        "phone": {
          "type": "string",
          "minLength": 1
        },
        "email": {
          "type": "string",
          "minLength": 1
        },
        "totalAreaSqFeet": {
          "type": "number",
          "format": "decimal"
        },
        "leasableAreaSqFeet": {
          "type": "number",
          "format": "decimal"
        },
        "totalUnits": {
          "type": "integer",
          "format": "int32"
        },
        "leasableUnits": {
          "type": "integer",
          "format": "int32"
        }
      }
    },
    "CreatePropertyBlock": {
      "type": "object",
      "required": [
        "propertyId",
        "blockName",
        "description",
        "status",
        "numberOfFloors",
        "totalUnits",
        "leasableUnits"
      ],
      "properties": {
        "propertyId": {
          "type": "integer",
          "format": "int64"
        },
        "blockName": {
          "type": "string",
          "minLength": 1
        },
        "description": {
          "type": "string"
        },
        "status": {
          "$ref": "#/definitions/BlockStatus"
        },
        "totalAreaSqFeet": {
          "type": "number",
          "format": "decimal"
        },
        "numberOfFloors": {
          "type": "integer",
          "format": "int32"
        },
        "totalUnits": {
          "type": "integer",
          "format": "int32"
        },
        "leasableUnits": {
          "type": "integer",
          "format": "int32"
        }
      }
    },
    "CreateUnitRequest": {
      "type": "object",
      "required": [
        "propertyId",
        "blockId",
        "unitNumber",
        "type",
        "description",
        "monthlyRent",
        "bookingFeeType",
        "depositAmount",
        "depositPercentage",
        "serviceChargeAmount",
        "bookingFeePercentage",
        "floorNumber"
      ],
      "properties": {
        "propertyId": {
          "type": "integer",
          "format": "int64"
        },
        "blockId": {
          "type": "integer",
          "format": "int64"
        },
        "unitNumber": {
          "type": "string",
          "minLength": 1
        },
        "type": {
          "$ref": "#/definitions/UnitType"
        },
        "description": {
          "type": "string",
          "minLength": 1
        },
        "areaSqFeet": {
          "type": "number",
          "format": "decimal"
        },
        "monthlyRent": {
          "type": "number",
          "format": "decimal"
        },
        "bookingFeeType": {
          "type": "string",
          "minLength": 1
        },
        "depositAmount": {
          "type": "number",
          "format": "decimal"
        },
        "depositPercentage": {
          "type": "number",
          "format": "decimal"
        },
        "serviceChargeAmount": {
          "type": "number",
          "format": "decimal"
        },
        "bookingFeePercentage": {
          "type": "number",
          "format": "decimal"
        },
        "wing": {
          "type": "string"
        },
        "section": {
          "type": "string"
        },
        "floorNumber": {
          "type": "integer",
          "format": "int32"
        }
      }
    },
    "CreateTenantRequest": {
      "type": "object",
      "required": [
        "fullName",
        "email",
        "phoneNumber",
        "idNumber",
        "businessName",
        "businessRegistrationNumber",
        "taxPin",
        "businessType",
        "emergencyContactName",
        "emergencyContactPhone",
        "emergencyContactEmail"
      ],
      "properties": {
        "fullName": {
          "type": "string",
          "minLength": 1
        },
        "email": {
          "type": "string"
        },
        "phoneNumber": {
          "type": "string",
          "minLength": 1
        },
        "idNumber": {
          "type": "string",
          "minLength": 1
        },
        "businessName": {
          "type": "string",
          "minLength": 1
        },
        "businessRegistrationNumber": {
          "type": "string"
        },
        "taxPin": {
          "type": "string"
        },
        "businessType": {
          "type": "string",
          "minLength": 1
        },
        "emergencyContactName": {
          "type": "string"
        },
        "emergencyContactPhone": {
          "type": "string"
        },
        "emergencyContactEmail": {
          "type": "string"
        }
      }
    },
    "AssignTenantToUnitRequest": {
      "type": "object",
      "required": [
        "unitId",
        "tenantId",
        "startDate",
        "leaseAgreementUrls"
      ],
      "properties": {
        "unitId": {
          "type": "integer",
          "format": "int64"
        },
        "tenantId": {
          "type": "integer",
          "format": "int64"
        },
        "startDate": {
          "type": "string",
          "format": "date-time",
          "minLength": 1
        },
        "leaseAgreementUrls": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "UnassignUnitRequest": {
      "type": "object",
      "required": [
        "unitId",
        "tenantId",
        "reason"
      ],
      "properties": {
        "unitId": {
          "type": "integer",
          "format": "int64"
        },
        "tenantId": {
          "type": "integer",
          "format": "int64"
        },
        "reason": {
          "type": "string",
          "minLength": 1
        }
      }
    },
    "IdentityRole": {
      "allOf": [
        {
          "$ref": "#/definitions/IdentityRoleOfString"
        },
        {
          "type": "object"
        }
      ]
    },
    "IdentityRoleOfString": {
      "type": "object",
      "properties": {
        "id": {
          "type": "string"
        },
        "name": {
          "type": "string"
        },
        "normalizedName": {
          "type": "string"
        },
        "concurrencyStamp": {
          "type": "string"
        }
      }
    },
    "UserWithRolesResponse": {
      "type": "object",
      "required": [
        "id",
        "userName",
        "normalizedUserName",
        "email",
        "normalizedEmail",
        "emailConfirmed",
        "phoneNumber",
        "phoneNumberConfirmed",
        "twoFactorEnabled",
        "lockoutEnabled",
        "accessFailedCount",
        "roles"
      ],
      "properties": {
        "id": {
          "type": "string"
        },
        "userName": {
          "type": "string"
        },
        "normalizedUserName": {
          "type": "string"
        },
        "email": {
          "type": "string"
        },
        "normalizedEmail": {
          "type": "string"
        },
        "emailConfirmed": {
          "type": "boolean"
        },
        "phoneNumber": {
          "type": "string"
        },
        "phoneNumberConfirmed": {
          "type": "boolean"
        },
        "twoFactorEnabled": {
          "type": "boolean"
        },
        "lockoutEnd": {
          "type": "string",
          "format": "date-time"
        },
        "lockoutEnabled": {
          "type": "boolean"
        },
        "accessFailedCount": {
          "type": "integer",
          "format": "int32"
        },
        "roles": {
          "type": "array",
          "items": {
            "type": "string"
          }
        }
      }
    },
    "Claim": {
      "type": "object",
      "required": [
        "issuer",
        "originalIssuer",
        "properties",
        "type",
        "value",
        "valueType"
      ],
      "properties": {
        "customSerializationData": {
          "type": "string",
          "format": "byte"
        },
        "issuer": {
          "type": "string"
        },
        "originalIssuer": {
          "type": "string"
        },
        "properties": {
          "type": "object",
          "additionalProperties": {
            "type": "string"
          }
        },
        "subject": {
          "$ref": "#/definitions/ClaimsIdentity"
        },
        "type": {
          "type": "string"
        },
        "value": {
          "type": "string"
        },
        "valueType": {
          "type": "string"
        }
      }
    },
    "ClaimsIdentity": {
      "type": "object",
      "required": [
        "isAuthenticated",
        "claims",
        "externalClaims",
        "nameClaimType",
        "roleClaimType"
      ],
      "properties": {
        "authenticationType": {
          "type": "string"
        },
        "isAuthenticated": {
          "type": "boolean"
        },
        "actor": {
          "$ref": "#/definitions/ClaimsIdentity"
        },
        "bootstrapContext": {},
        "claims": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Claim"
          }
        },
        "customSerializationData": {
          "type": "string",
          "format": "byte"
        },
        "externalClaims": {
          "type": "array",
          "items": {
            "type": "array",
            "items": {
              "$ref": "#/definitions/Claim"
            }
          }
        },
        "label": {
          "type": "string"
        },
        "name": {
          "type": "string"
        },
        "nameClaimType": {
          "type": "string"
        },
        "roleClaimType": {
          "type": "string"
        }
      }
    }
  },
  "securityDefinitions": {
    "Bearer": {
      "type": "apiKey",
      "name": "Authorization",
      "in": "header"
    }
  },
  "security": [
    {
      "Bearer": []
    }
  ]
}