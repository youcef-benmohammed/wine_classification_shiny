# Import libraries
library(tidyverse)
library(shiny)
library(shinythemes)
library(data.table)
library(randomForest)
library(shinyWidgets)
library(treemapify)

# Read data
wine <- read.csv("wine.data.csv")%>%
  mutate(cultivar=as.factor( c('Barolo','Grignolino','Barbera'))[ cultivar ] )

# Build model
model <- randomForest(cultivar ~ ., data = wine, ntree = 500, mtry = 13, importance = TRUE)

# Save model RDS file
saveRDS(model, "wine_model.rds")
model <- readRDS("wine_model.rds")

####################################
# User interface                   #
####################################


ui <- fluidPage(
  tabsetPanel(
    tabPanel("Predictions",
             theme = shinytheme("united"),
             tags$head(
               tags$style(
                 HTML('
      body {
                        background-image: url("https://us.images.westend61.com/0000732744pw/red-wine-splashing-in-glass-in-front-of-white-background-CPF000031.jpg");
                        background-size: cover;
                        background-repeat: no-repeat;
                        ground-attachment: fixed;
                      }
                      '
                 )
               )
             ),                
             # Page header
             headerPanel('Wine Cultivar'),
             
             # Input values
             sidebarPanel(
               HTML("<h3>Input parameters</h3>"),
               
               numericInput("alcohol", label = "Alcohol:", 
                            min = 10, max = 15,
                            value = 10, step= 0.01),
               numericInput("malic.acid", "Malic acid:",
                            min = 0, max = 6,
                            value = 0, step= 0.001),
               numericInput("ash", "Ash:",
                            min = 1, max = 4,
                            value = 1, step= 0.001),
               numericInput("alcalinity.of.ash", "Alcalinity of Ash:",
                            min = 10, max = 30,
                            value = 10, step= 0.01),
               numericInput("magnesium", "Magnesium:",
                            min = 70, max = 200,
                            value = 70, step= 0.01),
               numericInput("total.phenols", "Total phenols:",
                            min = 0, max = 4,
                            value = 0, step= 0.001),
               numericInput("flavnoids", "Flavnoids:",
                            min = 0, max = 6,
                            value = 0, step= 0.001),
               numericInput("nonflavnoid.phenols", "Non-Flavnoid Phenols:",
                            min = 0, max = 1, 
                            value = 0, step= 0.0001
               ),
               numericInput("proanthocyanins", "Proanthocyanins:",
                            min = 0, max = 4,
                            value = 0, step= 0.001),
               numericInput("color.intensity", "Color intensity:",
                            min = 1, max = 13,
                            value = 0, step= 0.001),
               numericInput("hue", "Hue:",
                            min = 0, max = 2,
                            value = 0, step= 0.0001),
               numericInput("od280.od315.of.diluted.wines", "od280 od315 of diluted wines:",
                            min = 1, max = 4,
                            value = 1, step= 0.001),
               numericInput("proline", "Proline:",
                            min = 100, max = 2000,
                            value = 100, step= 0.1),
               actionButton("submitbutton", "Submit", class = "btn btn-primary")
             ),
             
             mainPanel(
               tags$label(h3('Status/Output')), # Status/Output Text Box
               verbatimTextOutput('contents'),
               tableOutput('tabledata') # Prediction results table
             ),
             fileInput("uploadFile", "Upload data",
                       accept = c('text/csv', 'text/comma-separated-values',
                                  'text/plain', '.csv')
             ),
             actionButton("predictButton", "Get predictions", class="btn btn-primary"),
             downloadButton("downloadPredictions", "Download Predictions")
             
    )
  ),
    tabPanel("Visualization"),
             headerPanel('Wine Cultivar'),           
             plotOutput('treeMap')       
    

)

####################################
# Server                           #
####################################

server <- function(input, output, session) {
  performPredictions <- function(data) {
    predictions <- predict(model, data)
    output_df <- data.frame(Data = data, Prediction = predictions)
    return(output_df)
  }
  observeEvent(input$predictButton, {
    req(input$uploadFile)  # Check if a file has been uploaded
    
    # Generate a unique filename for predictions
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    prediction_file <- paste0("predictions_", timestamp, ".csv")
    
    inFile <- input$uploadFile
    df_ <- read.csv(inFile$datapath)
    predictions <- predict(model, df_)
    output_df <- data.frame(Data = df_, Prediction = predictions)
    
    # Save predictions to a file with a unique name
    write.csv(output_df, prediction_file, row.names = FALSE)
  })
  
  # Define downloadHandler outside the reactivity
  output$downloadPredictions <- downloadHandler(
    filename = function() {
      if (!is.null(input$uploadFile)) {
        paste0("predictions_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      }
    },
    content = function(file) {
      if (!is.null(input$uploadFile)) {
        inFile <- input$uploadFile
        df_ <- read.csv(inFile$datapath)
        predictions <- predict(model, df_)
        output_df <- data.frame(Data = df_, Prediction = predictions)
        write.csv(output_df, file, row.names = FALSE)
      }
    }
  )
  
  # Function to process input data for prediction
  datasetInput <- reactive({
    df <- data.frame(
      Name = c("alcohol", "malic.acid",  "ash", "alcalinity.of.ash",
               "magnesium", "total.phenols", "flavonoids", "nonflavonoid.phenols", 
               "proanthocyanins", "color.intensity",  "hue",    "od280.od315.of.diluted.wines", "proline"),
      Value = as.character(c(input$alcohol,
                             input$malic.acid,
                             input$ash,
                             input$alcalinity.of.ash,
                             input$magnesium,
                             input$total.phenols,
                             input$flavnoids,
                             input$nonflavnoid.phenols,
                             input$proanthocyanins,
                             input$color.intensity,
                             input$hue,
                             input$od280.od315.of.diluted.wines,
                             input$proline
      )),
      stringsAsFactors = FALSE
    )
    return(df)
  })
  
  # Status/Output Text Box
  output$contents <- renderPrint({
    if (input$submitbutton > 0) { 
      isolate("Calculation complete.") 
    } else {
      return("Server is ready for calculation.")
    }
  })
  
  # Prediction results table
  output$tabledata <- renderTable({
    if (input$submitbutton > 0) { 
      isolate(performPredictions(datasetInput()$Value)) 
    } 
  })
  # Generate and render the treemap plot
  output$treeMap <- renderPlot({
    req(input$predictButton, input$uploadFile)  # Ensure predictButton is clicked and file is uploaded
    inFile <- input$uploadFile
    df <- read.csv(inFile$datapath)
    
    predictions <- predict(model, df)
    output_df <- data.frame(Data = df, Prediction = predictions)
    
    output_df_summary <- output_df %>%
      group_by(Prediction) %>%
      summarise(count = n())
    
    ggplot(output_df_summary, aes(area = count, fill = Prediction, label = paste0(round((count / sum(count) * 100), 2), "%"))) +
      geom_treemap() +
      labs(title = "Treemap based on Predictions", fill = "Prediction") +
      geom_treemap_text()
  })
}

####################################
# Create the shiny app             #
####################################
shinyApp(ui = ui, server = server)
